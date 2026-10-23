"""Build and evaluate an isolated standalone XGBoost candidate model for FraudLens.

This candidate predicts fraud using the canonical 14 features from features.py,
without Isolation Forest or an iso_score feature.

All generated artifacts are saved strictly into:
    ml/artifacts/candidate_standalone_xgb/
Production artifacts and database are never modified.
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import (
    average_precision_score,
    brier_score_loss,
    log_loss,
    precision_recall_curve,
    roc_auc_score,
)
from xgboost import XGBClassifier

# Ensure imports resolve relative to ml/src
SRC_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SRC_DIR))

from config import ARTIFACTS, FEATURES_PARQUET
from features import FEATURES

CANDIDATE_DIR = ARTIFACTS / "candidate_standalone_xgb"
VAL_START = pd.Timestamp("2020-03-01")
SEED = 42
REVIEW_COST = 5.0
THRESHOLD_GRID = np.round(np.arange(0.01, 1.00, 0.01), 2)

FORBIDDEN_COLUMNS = {
    "is_fraud", "cc_num", "trans_num", "split", "merchant", "category",
    "trans_date_trans_time", "age", "gender_male", "log_city_pop",
    "card_prior_count", "iso_score",
}


def parse_args():
    parser = argparse.ArgumentParser(description="Build and evaluate standalone XGBoost candidate.")
    parser.add_argument(
        "--diagnostic",
        action="store_true",
        help="Run on a small stratified diagnostic sample (fast execution without full training).",
    )
    parser.add_argument(
        "--sample-fit",
        type=int,
        default=5000,
        help="Fit sample size in diagnostic mode (default 5000).",
    )
    return parser.parse_args()


def calculate_metrics(y_true, scores, amounts, threshold, review_cost=REVIEW_COST):
    """Calculate discrimination, calibration, operating metrics, and business costs."""
    y_true = np.asarray(y_true, dtype=int)
    scores = np.asarray(scores, dtype=float)
    amounts = np.asarray(amounts, dtype=float)

    # Sanity check probabilities
    if not np.all(np.isfinite(scores)):
        raise ValueError("Non-finite scores detected in evaluation!")
    if np.any((scores < 0.0) | (scores > 1.0)):
        raise ValueError("Scores outside [0, 1] range detected!")

    flagged = scores >= threshold
    fraud = y_true == 1

    tp = int((flagged & fraud).sum())
    fp = int((flagged & ~fraud).sum())
    fn = int((~flagged & fraud).sum())
    tn = int((~flagged & ~fraud).sum())
    alerts = tp + fp

    missed_fraud_loss = float(amounts[(~flagged) & fraud].sum())
    review_expense = float(alerts * review_cost)
    total_cost = missed_fraud_loss + review_expense
    no_model_cost = float(amounts[fraud].sum())
    savings = 1.0 - (total_cost / no_model_cost) if no_model_cost > 0 else 0.0

    return {
        "pr_auc": float(average_precision_score(y_true, scores)),
        "roc_auc": float(roc_auc_score(y_true, scores)),
        "brier_score": float(brier_score_loss(y_true, scores)),
        "log_loss": float(log_loss(y_true, scores)),
        "threshold": float(threshold),
        "alerts": alerts,
        "alerts_per_10k": float(10000.0 * alerts / len(y_true)) if len(y_true) else 0.0,
        "tp": tp,
        "fp": fp,
        "fn": fn,
        "tn": tn,
        "precision": float(tp / alerts) if alerts > 0 else 0.0,
        "recall": float(tp / (tp + fn)) if (tp + fn) > 0 else 0.0,
        "specificity": float(tn / (tn + fp)) if (tn + fp) > 0 else 0.0,
        "missed_fraud_loss": missed_fraud_loss,
        "review_expense": review_expense,
        "total_cost": total_cost,
        "no_model_cost": no_model_cost,
        "savings_vs_no_model": float(savings),
    }


def select_validation_threshold(y_val, val_scores, val_amounts, review_cost=REVIEW_COST):
    """Select the operating threshold strictly on validation data to minimize business cost."""
    outcomes = [
        calculate_metrics(y_val, val_scores, val_amounts, thr, review_cost)
        for thr in THRESHOLD_GRID
    ]
    best_outcome = min(outcomes, key=lambda o: o["total_cost"])
    return best_outcome["threshold"], best_outcome


def false_positive_breakdown(df_eval, scores, threshold):
    """Analyze false alarms across categories and daytime vs. night."""
    d = df_eval.copy()
    d["flagged"] = np.asarray(scores) >= threshold
    legit = d[d["is_fraud"] == 0]

    by_category = legit.groupby("category")["flagged"].agg(
        legit_txns="size",
        false_alerts="sum",
        fp_rate="mean",
    ).sort_values("false_alerts", ascending=False)

    by_night = legit.groupby("is_night")["flagged"].agg(
        legit_txns="size",
        false_alerts="sum",
        fp_rate="mean",
    )

    return {
        "by_category": by_category.head(5).to_dict(orient="index"),
        "by_night": by_night.to_dict(orient="index"),
    }


def main():
    args = parse_args()
    print("===============================================================")
    print("FraudLens ML Candidate: Standalone XGBoost (Without IsoScore)")
    print("===============================================================")
    print(f"Mode: {'DIAGNOSTIC (Sampled)' if args.diagnostic else 'FULL TRAINING'}")

    # 1. Feature verification
    feature_cols = list(FEATURES)
    assert len(feature_cols) == 14, f"Expected 14 features, got {len(feature_cols)}"
    intersection = FORBIDDEN_COLUMNS.intersection(set(feature_cols))
    assert not intersection, f"Forbidden columns in candidate feature list: {intersection}"
    print(f"Verified {len(feature_cols)} canonical features in exact order.")

    # 2. Data loading and partitioning
    print(f"Loading dataset from: {FEATURES_PARQUET}")
    df = pd.read_parquet(FEATURES_PARQUET)
    ts = df["trans_date_trans_time"]
    is_train = df["split"] == "train"

    fit_df = df[is_train & (ts < VAL_START)].copy()
    val_df = df[is_train & (ts >= VAL_START)].copy()
    test_df = df[df["split"] == "test"].copy()

    if args.diagnostic:
        print(f"\n[DIAGNOSTIC] Downsampling data for rapid validation check...")
        def sample_strat(d, n_legit, n_fraud, seed=SEED):
            legit = d[d["is_fraud"] == 0].sample(n=min(n_legit, int((d["is_fraud"] == 0).sum())), random_state=seed)
            fraud = d[d["is_fraud"] == 1].sample(n=min(n_fraud, int((d["is_fraud"] == 1).sum())), random_state=seed)
            return pd.concat([legit, fraud]).sort_values("trans_date_trans_time").reset_index(drop=True)

        fit_df = sample_strat(fit_df, n_legit=args.sample_fit, n_fraud=int(args.sample_fit * 0.05), seed=SEED)
        val_df = sample_strat(val_df, n_legit=2000, n_fraud=100, seed=SEED + 1)
        test_df = sample_strat(test_df, n_legit=2000, n_fraud=100, seed=SEED + 2)

    print(f"Partitions: fit={len(fit_df):,} rows (frauds: {fit_df.is_fraud.sum():,}), "
          f"val={len(val_df):,} rows (frauds: {val_df.is_fraud.sum():,}), "
          f"test={len(test_df):,} rows (frauds: {test_df.is_fraud.sum():,})")

    # 3. Model instantiation and training
    pos = int(fit_df["is_fraud"].sum())
    neg = len(fit_df) - pos
    scale_pos_weight = neg / pos

    print("\nTraining candidate XGBoost...")
    model = XGBClassifier(
        n_estimators=1000,
        learning_rate=0.05,
        max_depth=6,
        subsample=0.8,
        colsample_bytree=0.8,
        scale_pos_weight=scale_pos_weight,
        eval_metric="aucpr",
        early_stopping_rounds=50,
        tree_method="hist",
        n_jobs=-1,
        random_state=SEED,
    )

    model.fit(
        fit_df[feature_cols],
        fit_df["is_fraud"],
        eval_set=[(val_df[feature_cols], val_df["is_fraud"])],
        verbose=False,
    )
    print(f"Training completed. Best iteration: {model.best_iteration}")

    # 4. Booster verification
    booster_features = list(model.get_booster().feature_names)
    assert booster_features == feature_cols, "Booster feature names do not match canonical feature order!"
    assert "iso_score" not in booster_features, "iso_score found in candidate booster!"
    print("Booster features verified strictly matching canonical 14 features.")

    # 5. Predictions & Validation-only threshold selection
    val_scores = model.predict_proba(val_df[feature_cols])[:, 1]
    test_scores = model.predict_proba(test_df[feature_cols])[:, 1]

    opt_threshold, val_metrics = select_validation_threshold(
        val_df["is_fraud"], val_scores, val_df["amt"], review_cost=REVIEW_COST
    )
    print(f"\nOperating threshold selected on VALIDATION: {opt_threshold:.2f} (Review cost: ${REVIEW_COST:.2f})")

    # 6. Held-out test evaluation using validation threshold
    test_metrics = calculate_metrics(
        test_df["is_fraud"], test_scores, test_df["amt"], threshold=opt_threshold, review_cost=REVIEW_COST
    )

    # Comparison at benchmark threshold 0.20
    test_metrics_020 = calculate_metrics(
        test_df["is_fraud"], test_scores, test_df["amt"], threshold=0.20, review_cost=REVIEW_COST
    )

    fp_analysis = false_positive_breakdown(test_df, test_scores, opt_threshold)

    # 7. Print comparative results
    print("\n===== CANDIDATE METRICS SUMMARY =====")
    print(f"Validation PR-AUC:               {val_metrics['pr_auc']:.4f}")
    print(f"Validation ROC-AUC:              {val_metrics['roc_auc']:.4f}")
    print(f"Validation Brier Score:          {val_metrics['brier_score']:.6f}")
    print(f"Validation Log Loss:             {val_metrics['log_loss']:.6f}")
    print(f"Selected Threshold:              {opt_threshold:.2f}")
    print(f"Validation Recall:               {val_metrics['recall']:.2%}")
    print(f"Validation Precision:            {val_metrics['precision']:.2%}")
    print(f"Validation Total Cost:           ${val_metrics['total_cost']:,.2f}")
    print("---------------------------------------------------------------")
    print(f"Test PR-AUC:                     {test_metrics['pr_auc']:.4f}")
    print(f"Test ROC-AUC:                    {test_metrics['roc_auc']:.4f}")
    print(f"Test Brier Score:                {test_metrics['brier_score']:.6f}")
    print(f"Test Log Loss:                   {test_metrics['log_loss']:.6f}")
    print(f"Test Recall (@ {opt_threshold:.2f}):            {test_metrics['recall']:.2%}")
    print(f"Test Precision (@ {opt_threshold:.2f}):         {test_metrics['precision']:.2%}")
    print(f"Test Specificity (@ {opt_threshold:.2f}):       {test_metrics['specificity']:.2%}")
    print(f"Test Alerts (@ {opt_threshold:.2f}):            {test_metrics['alerts']:,} ({test_metrics['alerts_per_10k']:.1f} per 10k)")
    print(f"Test False Positives:            {test_metrics['fp']:,}")
    print(f"Test False Negatives:            {test_metrics['fn']:,}")
    print(f"Test Total Cost (@ {opt_threshold:.2f}):        ${test_metrics['total_cost']:,.2f}")
    print(f"Test Dollar Savings (@ {opt_threshold:.2f}):    {test_metrics['savings_vs_no_model']:.2%}")
    print("---------------------------------------------------------------")
    print(f"Test Recall (@ threshold 0.20):  {test_metrics_020['recall']:.2%}")
    print(f"Test Precision (@ threshold 0.20): {test_metrics_020['precision']:.2%}")
    print(f"Test Total Cost (@ threshold 0.20): ${test_metrics_020['total_cost']:,.2f}")

    # 8. Save isolated candidate artifacts
    CANDIDATE_DIR.mkdir(parents=True, exist_ok=True)
    model_save_path = CANDIDATE_DIR / "xgb_model.joblib"
    thresh_save_path = CANDIDATE_DIR / "threshold.json"
    metadata_save_path = CANDIDATE_DIR / "metadata.json"

    joblib.dump(model, model_save_path)
    thresh_save_path.write_text(
        json.dumps({"threshold": opt_threshold, "review_cost": REVIEW_COST}, indent=2),
        encoding="utf-8",
    )

    metadata = {
        "candidate": "candidate_standalone_xgb",
        "diagnostic_mode": args.diagnostic,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "method": "Standalone XGBClassifier trained on canonical 14 raw features without Isolation Forest",
        "seed": SEED,
        "features": feature_cols,
        "hyperparameters": {
            "n_estimators": 1000,
            "learning_rate": 0.05,
            "max_depth": 6,
            "subsample": 0.8,
            "colsample_bytree": 0.8,
            "scale_pos_weight": float(scale_pos_weight),
            "eval_metric": "aucpr",
            "early_stopping_rounds": 50,
            "tree_method": "hist",
            "best_iteration": int(model.best_iteration),
        },
        "operating_threshold": opt_threshold,
        "review_cost": REVIEW_COST,
        "validation_metrics": val_metrics,
        "test_metrics_at_selected_threshold": test_metrics,
        "test_metrics_at_threshold_020": test_metrics_020,
        "false_positive_analysis": fp_analysis,
        "note": "Candidate model isolated from production inference.",
    }
    metadata_save_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    print(f"\nCandidate artifacts saved successfully into: {CANDIDATE_DIR}")
    print(f"  - Model:     {model_save_path.name}")
    print(f"  - Threshold: {thresh_save_path.name} (threshold={opt_threshold:.2f})")
    print(f"  - Metadata:  {metadata_save_path.name}")
    print("Production artifacts remain completely untouched.")


if __name__ == "__main__":
    main()
