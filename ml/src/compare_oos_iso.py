
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.metrics import average_precision_score, roc_auc_score
from xgboost import XGBClassifier

sys.path.insert(0, str(Path(__file__).resolve().parent))

from config import FEATURES_PARQUET
from features import FEATURES


SEED = 42
VAL_START = pd.Timestamp("2020-03-01")
REVIEW_COST = 5.0
WARMUP_FRACTION = 0.25
THRESHOLD_GRID = np.round(np.arange(0.01, 1.00, 0.01), 2)

IF_FEATURES = [feature for feature in FEATURES if feature != "category_code"]
COMBINED_FEATURES = FEATURES + ["iso_score"]


def train_xgb(train_data, early_stop_data, columns, model_name):
    """Train XGBoost using a chronological validation segment."""
    positives = int(train_data["is_fraud"].sum())
    negatives = len(train_data) - positives

    if positives == 0 or negatives == 0:
        raise ValueError(
            f"{model_name} training data must contain both classes."
        )

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
        train_data[columns],
        train_data["is_fraud"],
        eval_set=[
            (early_stop_data[columns], early_stop_data["is_fraud"])
        ],
        verbose=False,
    )

    print(f"{model_name} best iteration: {model.best_iteration}")
    return model


def calculate_outcome(data, scores, threshold):
    """Calculate detection counts and assumed transaction/review costs."""
    actual_fraud = data["is_fraud"].to_numpy() == 1
    flagged = np.asarray(scores) >= threshold
    amounts = data["amt"].to_numpy()

    tp = int((flagged & actual_fraud).sum())
    fp = int((flagged & ~actual_fraud).sum())
    fn = int((~flagged & actual_fraud).sum())
    tn = int((~flagged & ~actual_fraud).sum())

    alerts = tp + fp
    precision = tp / alerts if alerts else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    specificity = tn / (tn + fp) if (tn + fp) else 0.0

    missed_fraud_amount = float(
        amounts[(~flagged) & actual_fraud].sum()
    )
    review_cost = alerts * REVIEW_COST

    return {
        "threshold": float(threshold),
        "alerts": alerts,
        "tp": tp,
        "fp": fp,
        "fn": fn,
        "tn": tn,
        "precision": precision,
        "recall": recall,
        "specificity": specificity,
        "review_cost": review_cost,
        "missed_fraud_amount": missed_fraud_amount,
        "estimated_total_cost": missed_fraud_amount + review_cost,
        "alerts_per_10k": 10_000 * alerts / len(data),
    }


def choose_threshold(validation_data, validation_scores):
    """Select the lowest-cost threshold using validation labels only."""
    outcomes = [
        calculate_outcome(validation_data, validation_scores, threshold)
        for threshold in THRESHOLD_GRID
    ]

    best_index = int(
        np.argmin([item["estimated_total_cost"] for item in outcomes])
    )
    return outcomes[best_index]["threshold"]


def evaluate(model, columns, validation, test, model_name):
    """Select a threshold on validation and evaluate both datasets."""
    validation_scores = model.predict_proba(validation[columns])[:, 1]
    test_scores = model.predict_proba(test[columns])[:, 1]

    threshold = choose_threshold(validation, validation_scores)

    validation_outcome = calculate_outcome(
        validation, validation_scores, threshold
    )
    test_outcome = calculate_outcome(test, test_scores, threshold)

    return [
        {
            "dataset": "Validation (threshold-selected)",
            "model": model_name,
            "pr_auc": average_precision_score(
                validation["is_fraud"], validation_scores
            ),
            "roc_auc": roc_auc_score(
                validation["is_fraud"], validation_scores
            ),
            **validation_outcome,
        },
        {
            "dataset": "Test (exploratory only)",
            "model": model_name,
            "pr_auc": average_precision_score(
                test["is_fraud"], test_scores
            ),
            "roc_auc": roc_auc_score(
                test["is_fraud"], test_scores
            ),
            **test_outcome,
        },
    ]


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

    if len(fit) < 10 or validation.empty or test.empty:
        raise ValueError("A required dataset split is empty or too small.")

    warmup_size = max(1, int(len(fit) * WARMUP_FRACTION))
    warmup = fit.iloc[:warmup_size].copy()
    xgb_fit = fit.iloc[warmup_size:].copy()

    # Use the earlier half of validation for early stopping and the
    # later half to select the alert threshold.
    split_index = len(validation) // 2
    early_stop = validation.iloc[:split_index].copy()
    threshold_validation = validation.iloc[split_index:].copy()

    if (
        early_stop.empty
        or threshold_validation.empty
        or early_stop["is_fraud"].nunique() < 2
        or threshold_validation["is_fraud"].nunique() < 2
    ):
        raise ValueError(
            "Both chronological validation segments must contain "
            "fraud and non-fraud rows. Review the split before proceeding."
        )

    if xgb_fit["is_fraud"].nunique() < 2:
        raise ValueError("XGBoost training data must contain both classes.")

    print("\n===== DATA SPLITS =====")
    print(f"Isolation Forest warm-up:       {len(warmup):,}")
    print(f"XGBoost training rows:          {len(xgb_fit):,}")
    print(f"Early-stopping validation rows: {len(early_stop):,}")
    print(f"Threshold-selection rows:       {len(threshold_validation):,}")
    print(f"Test rows:                      {len(test):,}")
    print(
        "Early-stopping period:",
        early_stop["trans_date_trans_time"].min(),
        "to",
        early_stop["trans_date_trans_time"].max(),
    )
    print(
        "Threshold-selection period:",
        threshold_validation["trans_date_trans_time"].min(),
        "to",
        threshold_validation["trans_date_trans_time"].max(),
    )

    # Fit Isolation Forest only on the earliest historical warm-up rows.
    print("\nTraining Isolation Forest...")
    iso = IsolationForest(
        n_estimators=200,
        max_samples=256,
        random_state=SEED,
        n_jobs=-1,
    )
    iso.fit(warmup[IF_FEATURES])

    # Generate the same type of frozen-model score for every later split.
    for part in (xgb_fit, early_stop, threshold_validation, test):
        part["iso_score"] = -iso.score_samples(part[IF_FEATURES])

    # Both XGBoost models use identical training and early-stop rows.
    print("\nTraining baseline XGBoost...")
    baseline = train_xgb(
        xgb_fit, early_stop, FEATURES, "XGBoost"
    )

    print("\nTraining XGBoost + Isolation Forest score...")
    combined = train_xgb(
        xgb_fit, early_stop, COMBINED_FEATURES, "XGBoost + IsoScore"
    )

    results = []
    results.extend(
        evaluate(
            baseline,
            FEATURES,
            threshold_validation,
            test,
            "XGBoost",
        )
    )
    results.extend(
        evaluate(
            combined,
            COMBINED_FEATURES,
            threshold_validation,
            test,
            "XGBoost + IsoScore",
        )
    )

    result_table = pd.DataFrame(results)

    print("\n===== RESULTS =====")
    columns_to_show = [
        "dataset",
        "model",
        "pr_auc",
        "roc_auc",
        "threshold",
        "alerts",
        "tp",
        "fp",
        "fn",
        "precision",
        "recall",
        "specificity",
        "review_cost",
        "missed_fraud_amount",
        "estimated_total_cost",
        "alerts_per_10k",
    ]
    print(
        result_table[columns_to_show]
        .round(4)
        .to_string(index=False)
    )

    print("\n===== NOTES =====")
    print(f"Assumed review cost per alert: ${REVIEW_COST:.2f}")
    print("Thresholds are selected only on the later validation segment.")
    print("The earlier validation segment is used for early stopping.")
    print("Test results are exploratory; the test set has been examined before.")
    print("No model, threshold, or metrics artifacts were saved.")


if __name__ == "__main__":
    main()
