
import os
import sys
import json
from datetime import timedelta
from pathlib import Path

import django
import joblib
import pandas as pd


BACKEND_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BACKEND_DIR.parent
CANDIDATE_DIR = PROJECT_ROOT / "ml" / "artifacts" / "candidate_oos"

# Ensure Python can import the Django project and its applications.
sys.path.insert(0, str(BACKEND_DIR))

# Correct settings module for this project.
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

django.setup()

from django.conf import settings
from django.utils import timezone


def main():
    from transactions.models import Transaction
    from transactions import ml_service

    required_files = [
        "isolation_forest.joblib",
        "xgb_with_iso.joblib",
        "threshold.json",
        "metadata.json",
    ]

    print("===== CANDIDATE FILE CHECK =====")

    for filename in required_files:
        path = CANDIDATE_DIR / filename

        if not path.is_file():
            raise FileNotFoundError(f"Missing candidate file: {path}")

        print(f"Found: {filename}")

    # Read metadata and candidate models without modifying them.
    metadata_path = CANDIDATE_DIR / "metadata.json"

    with metadata_path.open("r", encoding="utf-8") as file:
        metadata = json.load(file)

    iso = joblib.load(CANDIDATE_DIR / "isolation_forest.joblib")
    model = joblib.load(CANDIDATE_DIR / "xgb_with_iso.joblib")

    expected_if_features = metadata["if_features"]
    expected_xgb_features = metadata["xgb_features"]

    actual_if_features = list(iso.feature_names_in_)
    actual_xgb_features = list(model.get_booster().feature_names)

    print("\n===== FEATURE COMPATIBILITY =====")
    print(f"Isolation Forest feature count: {len(actual_if_features)}")
    print(f"XGBoost feature count:          {len(actual_xgb_features)}")

    if actual_if_features != expected_if_features:
        raise AssertionError(
            "Candidate Isolation Forest feature names/order "
            "do not match metadata."
        )

    if actual_xgb_features != expected_xgb_features:
        raise AssertionError(
            "Candidate XGBoost feature names/order do not match metadata."
        )

    if "iso_score" not in actual_xgb_features:
        raise AssertionError("Candidate XGBoost model is missing iso_score.")

    print("Feature names and order match candidate metadata.")

    # Redirect model loading only within this Python process.
    # This does not edit settings.py or production artifacts.
    original_artifact_dir = getattr(settings, "ML_ARTIFACTS_DIR", None)
    settings.ML_ARTIFACTS_DIR = str(CANDIDATE_DIR)
    ml_service.get_bundle.cache_clear()

    try:
        bundle = ml_service.get_bundle()

        if list(bundle.if_cols) != expected_if_features:
            raise AssertionError(
                "Django loaded unexpected Isolation Forest columns."
            )

        if list(bundle.xgb_cols) != expected_xgb_features:
            raise AssertionError(
                "Django loaded unexpected XGBoost columns."
            )

        print("\n===== DJANGO BUNDLE CHECK =====")
        print(f"Loaded candidate threshold: {bundle.threshold:.4f}")
        print(f"Expected threshold:         {metadata['threshold']:.4f}")

        if abs(bundle.threshold - metadata["threshold"]) > 1e-12:
            raise AssertionError(
                "Django loaded a threshold different from metadata."
            )

        # Read an existing transaction for its card and transaction details.
        # Score a hypothetical transaction; do not save it to the database.
        latest = (
            Transaction.objects.select_related("card")
            .order_by("-occurred_at")
            .first()
        )

        if latest is None:
            raise RuntimeError(
                "No existing transaction is available for the "
                "read-only scoring check."
            )

        occurred_at = latest.occurred_at + timedelta(seconds=1)

        if timezone.is_naive(occurred_at):
            occurred_at = timezone.make_aware(
                occurred_at, timezone.get_current_timezone()
            )

        result = ml_service.score_transaction(
            card=latest.card,
            occurred_at=occurred_at,
            merchant=f"{latest.merchant} candidate-check",
            category=latest.category,
            amount=float(latest.amount),
        )

        print("\n===== LIVE SCORING CHECK =====")
        print(f"Score:     {result['score']:.6f}")
        print(f"Threshold: {result['threshold']:.6f}")
        print(f"Flagged:   {result['flagged']}")
        print(f"Reasons returned: {len(result['reasons'])}")
        print(
            "Feature count (without derived iso_score): "
            f"{len(result['features'])}"
        )

        if not 0.0 <= result["score"] <= 1.0:
            raise AssertionError(
                "Scoring returned a probability outside [0, 1]."
            )

        # Exercise the explanation interface even if the transaction
        # does not cross the alert threshold.
        row = pd.DataFrame([result["features"]])
        row["iso_score"] = -bundle.iso.score_samples(row[bundle.if_cols])
        row = row[bundle.xgb_cols]

        explanation = bundle.explain.explain(bundle.model, row)

        if explanation is None:
            raise AssertionError("Explanation function returned None.")

        if isinstance(explanation, (list, tuple)):
            if len(explanation) != 1:
                raise AssertionError(
                    "Expected one explanation for one transaction; "
                    f"received {len(explanation)}."
                )
        elif isinstance(explanation, pd.DataFrame):
            if len(explanation) != 1:
                raise AssertionError(
                    "Expected one explanation row; "
                    f"received {len(explanation)}."
                )
        else:
            print(
                "Explanation returned type: "
                f"{type(explanation).__name__}"
            )

        print("Explanation interface: OK")
        print("\nPASS: candidate loaded and scored through Django.")
        print("No transaction was inserted or updated.")
        print("No production model artifacts or settings file were changed.")

    finally:
        # Restore the original in-memory setting and clear the cached bundle.
        if original_artifact_dir is not None:
            settings.ML_ARTIFACTS_DIR = original_artifact_dir
        elif hasattr(settings, "ML_ARTIFACTS_DIR"):
            delattr(settings, "ML_ARTIFACTS_DIR")

        ml_service.get_bundle.cache_clear()


if __name__ == "__main__":
    main()
