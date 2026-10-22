
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.metrics import average_precision_score, roc_auc_score
from xgboost import XGBClassifier

sys.path.insert(0, str(Path(__file__).resolve().parent))

from config import FEATURES_PARQUET, ARTIFACTS
from features import FEATURES


SEED = 42
VAL_START = pd.Timestamp("2020-03-01")
REVIEW_COST = 5.0
WARMUP_FRACTION = 0.25
THRESHOLD_GRID = np.round(np.arange(0.01, 1.00, 0.01), 2)

IF_FEATURES = [f for f in FEATURES if f != "category_code"]
XGB_FEATURES = FEATURES + ["iso_score"]

# Crucially, this directory is separate from production artifacts.
CANDIDATE_DIR = ARTIFACTS / "candidate_oos"


def calculate_outcome(data, scores, threshold):
    actual = data["is_fraud"].to_numpy() == 1
    flagged = np.asarray(scores) >= threshold
    amounts = data["amt"].to_numpy()

    tp = int((flagged & actual).sum())
    fp = int((flagged & ~actual).sum())
    fn = int((~flagged & actual).sum())
    tn = int((~flagged & ~actual).sum())

    alerts = tp + fp
    missed_amount = float(amounts[(~flagged) & actual].sum())
    review_cost = alerts * REVIEW_COST

    return {
        "threshold": float(threshold),
        "alerts": alerts,
        "tp": tp,
        "fp": fp,
        "fn": fn,
        "tn": tn,
        "precision": tp / alerts if alerts else 0.0,
        "recall": tp / (tp + fn) if (tp + fn) else 0.0,
        "specificity": tn / (tn + fp) if (tn + fp) else 0.0,
        "review_cost": float(review_cost),
        "missed_fraud_amount": missed_amount,
        "estimated_total_cost": float(review_cost + missed_amount),
        "alerts_per_10k": float(10000 * alerts / len(data)),
    }


def main():
    print("Loading existing features...")
    df = pd.read_parquet(FEATURES_PARQUET)
    timestamps = df["trans_date_trans_time"]

    fit = df[
        (df["split"] == "train") & (timestamps < VAL_START)
    ].copy()

    validation = df[
        (df["split"] == "train") & (timestamps >= VAL_START)
    ].copy()

    test = df[df["split"] == "test"].copy()

    fit = fit.sort_values("trans_date_trans_time").reset_index(drop=True)
    validation = validation.sort_values(
        "trans_date_trans_time"
    ).reset_index(drop=True)
    test = test.sort_values("trans_date_trans_time").reset_index(drop=True)

    warmup_size = max(1, int(len(fit) * WARMUP_FRACTION))
    warmup = fit.iloc[:warmup_size].copy()
    xgb_fit = fit.iloc[warmup_size:].copy()

    split_index = len(validation) // 2
    early_stop = validation.iloc[:split_index].copy()
    threshold_validation = validation.iloc[split_index:].copy()

    if (
        xgb_fit.empty
        or early_stop.empty
        or threshold_validation.empty
        or test.empty
        or xgb_fit["is_fraud"].nunique() != 2
        or early_stop["is_fraud"].nunique() != 2
        or threshold_validation["is_fraud"].nunique() != 2
    ):
        raise ValueError("A data split is empty or lacks both target classes.")

    print(f"Warm-up rows: {len(warmup):,}")
    print(f"XGBoost training rows: {len(xgb_fit):,}")
    print(f"Early-stop rows: {len(early_stop):,}")
    print(f"Threshold-validation rows: {len(threshold_validation):,}")
    print(f"Test rows: {len(test):,}")

    # Train Isolation Forest on historical warm-up data only.
    print("\nTraining Isolation Forest...")
    iso = IsolationForest(
        n_estimators=200,
        max_samples=256,
        random_state=SEED,
        n_jobs=-1,
    )
    iso.fit(warmup[IF_FEATURES])

    # Generate the same frozen-model anomaly score in every later split.
    for part in (xgb_fit, early_stop, threshold_validation, test):
        part["iso_score"] = -iso.score_samples(part[IF_FEATURES])

    positives = int(xgb_fit["is_fraud"].sum())
    negatives = len(xgb_fit) - positives

    print("\nTraining candidate XGBoost + Isolation Forest...")
    model = XGBClassifier(
        n_estimators=1000,
        learning_rate=0.05,
        max_depth=6,
        subsample=0.8,
        colsample_bytree=0.8,
        scale_pos_weight=negatives / positives,
        eval_metric="aucpr",
        early_stopping_rounds=50,
        tree_method="hist",
        n_jobs=-1,
        random_state=SEED,
    )

    model.fit(
        xgb_fit[XGB_FEATURES],
        xgb_fit["is_fraud"],
        eval_set=[
            (early_stop[XGB_FEATURES], early_stop["is_fraud"])
        ],
        verbose=False,
    )
    print(f"Best iteration: {model.best_iteration}")

    # Select threshold on the later validation segment only.
    validation_scores = model.predict_proba(
        threshold_validation[XGB_FEATURES]
    )[:, 1]

    validation_outcomes = [
        calculate_outcome(threshold_validation, validation_scores, threshold)
        for threshold in THRESHOLD_GRID
    ]
    best = min(
        validation_outcomes,
        key=lambda outcome: outcome["estimated_total_cost"],
    )
    threshold = best["threshold"]

    test_scores = model.predict_proba(test[XGB_FEATURES])[:, 1]

    validation_metrics = {
        "pr_auc": float(average_precision_score(
            threshold_validation["is_fraud"], validation_scores
        )),
        "roc_auc": float(roc_auc_score(
            threshold_validation["is_fraud"], validation_scores
        )),
        **best,
    }

    test_metrics = {
        "pr_auc": float(average_precision_score(
            test["is_fraud"], test_scores
        )),
        "roc_auc": float(roc_auc_score(
            test["is_fraud"], test_scores
        )),
        **calculate_outcome(test, test_scores, threshold),
    }

    # Create a new candidate directory; never write to production filenames.
    CANDIDATE_DIR.mkdir(parents=True, exist_ok=True)

    joblib.dump(iso, CANDIDATE_DIR / "isolation_forest.joblib")
    joblib.dump(model, CANDIDATE_DIR / "xgb_with_iso.joblib")

    threshold_data = {
        "threshold": threshold,
        "review_cost": REVIEW_COST,
    }
    (CANDIDATE_DIR / "threshold.json").write_text(
        json.dumps(threshold_data, indent=2),
        encoding="utf-8",
    )

    metadata = {
        "candidate": "candidate_oos",
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "method": (
            "Isolation Forest fitted on earliest 25% of pre-validation "
            "training period; XGBoost trained on remaining rows; "
            "threshold selected on later half of validation."
        ),
        "seed": SEED,
        "warmup_fraction": WARMUP_FRACTION,
        "warmup_rows": len(warmup),
        "xgb_training_rows": len(xgb_fit),
        "early_stop_rows": len(early_stop),
        "threshold_validation_rows": len(threshold_validation),
        "best_iteration": int(model.best_iteration),
        "if_features": IF_FEATURES,
        "xgb_features": XGB_FEATURES,
        "threshold": threshold,
        "review_cost": REVIEW_COST,
        "validation_metrics": validation_metrics,
        "test_metrics_exploratory_only": test_metrics,
        "test_warning": (
            "The existing test set has been examined in prior experiments. "
            "These metrics are exploratory, not an independent final benchmark."
        ),
    }

    (CANDIDATE_DIR / "metadata.json").write_text(
        json.dumps(metadata, indent=2),
        encoding="utf-8",
    )

    print("\n===== CANDIDATE SAVED =====")
    print(f"Directory: {CANDIDATE_DIR}")
    print(f"Threshold: {threshold:.2f}")
    print("\nValidation metrics:")
    print(json.dumps(validation_metrics, indent=2))
    print("\nExploratory test metrics:")
    print(json.dumps(test_metrics, indent=2))
    print("\nProduction artifacts were not modified.")


if __name__ == "__main__":
    main()
