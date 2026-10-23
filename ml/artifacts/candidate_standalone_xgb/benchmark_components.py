"""Reworked Rigorous Latency Benchmark for FraudLens Scoring Pipelines.

Methodology:
- Identical input rows drawn from the held-out test partition.
- Identical warm-up policy: 50 warm-up trials for both models.
- Identical repetition count: 1,000 trials per model.
- Precise timing boundaries for:
  a) Model-only scoring (inference only on pre-formatted features).
  b) End-to-end scoring (dict-to-result, excluding SHAP, representing >98.5% of traffic).
  c) TreeSHAP explanation timing (conditional branch, evaluated separately).

Safety: Offline execution only, no production endpoints, no database writes.
"""
from pathlib import Path
import sys
import time
import numpy as np
import pandas as pd
import joblib

CANDIDATE_DIR = Path(__file__).resolve().parent
ML_SRC = CANDIDATE_DIR.parent.parent / "src"
if str(ML_SRC) not in sys.path:
    sys.path.insert(0, str(ML_SRC))
if str(CANDIDATE_DIR) not in sys.path:
    sys.path.insert(0, str(CANDIDATE_DIR))

from features import FEATURES
from config import ARTIFACTS, FEATURES_PARQUET
import explain
import candidate_explain
from candidate_service import get_candidate_bundle, score_candidate_features


def benchmark(n_trials=1000, warmup_n=50):
    print("=" * 75)
    print("FRAUDLENS LATENCY & WORKLOAD BENCHMARK (STANDALONE vs PRODUCTION)")
    print("=" * 75)
    print(f"Configuration: Trials={n_trials:,}, Warmup={warmup_n}, Timer=time.perf_counter()")

    prod_xgb = joblib.load(ARTIFACTS / "xgb_with_iso.joblib")
    prod_iso = joblib.load(ARTIFACTS / "isolation_forest.joblib")
    cand_bundle = get_candidate_bundle()
    cand_xgb = cand_bundle.model

    df = pd.read_parquet(FEATURES_PARQUET)
    sample_df = df[df["split"] == "test"].head(n_trials).copy()
    assert len(sample_df) == n_trials, f"Expected {n_trials} rows, got {len(sample_df)}"

    IF_FEATURES = [f for f in FEATURES if f != "category_code"]
    XGB_ISO_FEATURES = FEATURES + ["iso_score"]

    # Pre-extract pre-formatted rows for model-only scoring
    prod_preformatted = []
    cand_preformatted = []
    raw_feature_dicts = []

    for i in range(n_trials):
        row = sample_df.iloc[[i]]
        d = {f: row[f].iloc[0] for f in FEATURES}
        raw_feature_dicts.append(d)

        # Pre-formatted for candidate
        cand_preformatted.append(row[FEATURES])

        # Pre-formatted for production (pre-computed iso_score)
        row_iso = row[FEATURES].copy()
        row_iso["iso_score"] = -prod_iso.score_samples(row[IF_FEATURES])[0]
        prod_preformatted.append(row_iso[XGB_ISO_FEATURES])

    # -------------------------------------------------------------
    # 1. Warm-up Phase (Identical 50 trials for all code paths)
    # -------------------------------------------------------------
    print(f"\nExecuting {warmup_n} warm-up iterations for both models...")
    for i in range(warmup_n):
        # Model-only warmup
        _ = prod_iso.score_samples(sample_df.iloc[[i]][IF_FEATURES])
        _ = prod_xgb.predict_proba(prod_preformatted[i])
        _ = cand_xgb.predict_proba(cand_preformatted[i])

        # End-to-end warmup
        row_p = pd.DataFrame([raw_feature_dicts[i]])
        row_p["iso_score"] = -prod_iso.score_samples(row_p[IF_FEATURES])
        _ = prod_xgb.predict_proba(row_p[XGB_ISO_FEATURES])
        _ = score_candidate_features(raw_feature_dicts[i], bundle=cand_bundle)

    # -------------------------------------------------------------
    # 2. Model-Only Scoring Benchmark (Pre-formatted features)
    # -------------------------------------------------------------
    print("\nMeasuring Model-Only Scoring (Inference on pre-formatted features)...")
    # Production Model-Only (IF scoring + XGBoost scoring)
    prod_model_only = []
    for i in range(n_trials):
        row_if = sample_df.iloc[[i]][IF_FEATURES]
        t0 = time.perf_counter()
        iso_val = -prod_iso.score_samples(row_if)[0]
        # In production inference, iso_score must be evaluated per transaction
        row_x = prod_preformatted[i]
        _ = prod_xgb.predict_proba(row_x)
        t_elapsed = (time.perf_counter() - t0) * 1000.0  # ms
        prod_model_only.append(t_elapsed)

    # Candidate Model-Only (XGBoost scoring alone)
    cand_model_only = []
    for i in range(n_trials):
        row_c = cand_preformatted[i]
        t0 = time.perf_counter()
        _ = cand_xgb.predict_proba(row_c)
        t_elapsed = (time.perf_counter() - t0) * 1000.0  # ms
        cand_model_only.append(t_elapsed)

    # -------------------------------------------------------------
    # 3. End-to-End Scoring Benchmark (From feature dict to decision)
    # -------------------------------------------------------------
    print("Measuring End-to-End Scoring (Raw feature dict -> validation -> scoring -> decision)...")
    prod_e2e = []
    for i in range(n_trials):
        feats = raw_feature_dicts[i]
        t0 = time.perf_counter()
        row = pd.DataFrame([feats])
        row["iso_score"] = -prod_iso.score_samples(row[IF_FEATURES])
        X = row[XGB_ISO_FEATURES]
        score = float(prod_xgb.predict_proba(X)[0, 1])
        flagged = score >= 0.20
        res = {
            "score": score,
            "flagged": flagged,
            "threshold": 0.20,
            "reasons": [],  # SHAP measured separately
            "features": feats,
        }
        t_elapsed = (time.perf_counter() - t0) * 1000.0  # ms
        prod_e2e.append(t_elapsed)

    cand_e2e = []
    for i in range(n_trials):
        feats = raw_feature_dicts[i]
        t0 = time.perf_counter()
        res = score_candidate_features(feats, threshold=0.20, bundle=cand_bundle)
        t_elapsed = (time.perf_counter() - t0) * 1000.0  # ms
        cand_e2e.append(t_elapsed)

    # -------------------------------------------------------------
    # 4. TreeSHAP Explanation Timing (Evaluated Separately on Flagged Txns)
    # -------------------------------------------------------------
    print("Measuring TreeSHAP Explanation (Conditional on flagged transactions)...")
    # Draw sample of suspicious transactions
    susp_sample = sample_df[sample_df["amt"] > 500].head(50).copy()
    if len(susp_sample) < 20:
        susp_sample = sample_df.head(50).copy()

    prod_shap_times = []
    for i in range(len(susp_sample)):
        row_iso = susp_sample.iloc[[i]][FEATURES].copy()
        row_iso["iso_score"] = -prod_iso.score_samples(susp_sample.iloc[[i]][IF_FEATURES])[0]
        X = row_iso[XGB_ISO_FEATURES]
        t0 = time.perf_counter()
        _ = explain.explain(prod_xgb, X)
        prod_shap_times.append((time.perf_counter() - t0) * 1000.0)

    cand_shap_times = []
    for i in range(len(susp_sample)):
        X = susp_sample.iloc[[i]][FEATURES]
        t0 = time.perf_counter()
        _ = candidate_explain.explain_candidate(cand_xgb, X)
        cand_shap_times.append((time.perf_counter() - t0) * 1000.0)

    # -------------------------------------------------------------
    # 5. Compile Statistical Comparison Table
    # -------------------------------------------------------------
    def get_stats(arr):
        return {
            "median": float(np.median(arr)),
            "p95": float(np.percentile(arr, 95)),
            "mean": float(np.mean(arr)),
            "min": float(np.min(arr)),
            "max": float(np.max(arr)),
            "throughput": float(1000.0 / np.mean(arr)) if np.mean(arr) > 0 else 0.0,
        }

    s_prod_mo = get_stats(prod_model_only)
    s_cand_mo = get_stats(cand_model_only)
    s_prod_e2e = get_stats(prod_e2e)
    s_cand_e2e = get_stats(cand_e2e)
    s_prod_shap = get_stats(prod_shap_times)
    s_cand_shap = get_stats(cand_shap_times)

    summary_table = [
        {
            "Workload / Timing Boundary": "Model-Only Scoring (Inference on pre-formatted features)",
            "Production (xgb_with_iso + IF) Median": f"{s_prod_mo['median']:.3f} ms",
            "Production p95": f"{s_prod_mo['p95']:.3f} ms",
            "Candidate (Standalone XGB) Median": f"{s_cand_mo['median']:.3f} ms",
            "Candidate p95": f"{s_cand_mo['p95']:.3f} ms",
            "Latency Delta (Cand vs Prod)": f"{s_cand_mo['median'] - s_prod_mo['median']:.3f} ms (-{(s_prod_mo['median'] - s_cand_mo['median'])/s_prod_mo['median']:.1%})",
        },
        {
            "Workload / Timing Boundary": "End-to-End Scoring (Dict -> DataFrame -> Scoring -> Result)",
            "Production (xgb_with_iso + IF) Median": f"{s_prod_e2e['median']:.3f} ms",
            "Production p95": f"{s_prod_e2e['p95']:.3f} ms",
            "Candidate (Standalone XGB) Median": f"{s_cand_e2e['median']:.3f} ms",
            "Candidate p95": f"{s_cand_e2e['p95']:.3f} ms",
            "Latency Delta (Cand vs Prod)": f"{s_cand_e2e['median'] - s_prod_e2e['median']:.3f} ms (-{(s_prod_e2e['median'] - s_cand_e2e['median'])/s_prod_e2e['median']:.1%})",
        },
        {
            "Workload / Timing Boundary": "TreeSHAP Explanation (Executed only when flagged)",
            "Production (xgb_with_iso + IF) Median": f"{s_prod_shap['median']:.3f} ms",
            "Production p95": f"{s_prod_shap['p95']:.3f} ms",
            "Candidate (Standalone XGB) Median": f"{s_cand_shap['median']:.3f} ms",
            "Candidate p95": f"{s_cand_shap['p95']:.3f} ms",
            "Latency Delta (Cand vs Prod)": f"{s_cand_shap['median'] - s_prod_shap['median']:.3f} ms (-{(s_prod_shap['median'] - s_cand_shap['median'])/s_prod_shap['median']:.1%})",
        },
    ]

    print("\n" + "=" * 75)
    print("BENCHMARK RESULTS (1,000 IDENTICAL TEST TRANSACTIONS)")
    print("=" * 75)
    for row in summary_table:
        print(f"\n>>> {row['Workload / Timing Boundary']}:")
        print(f"    Production: Median = {row['Production (xgb_with_iso + IF) Median']} | p95 = {row['Production p95']}")
        print(f"    Candidate:  Median = {row['Candidate (Standalone XGB) Median']} | p95 = {row['Candidate p95']}")
        print(f"    Difference: {row['Latency Delta (Cand vs Prod)']}")

    print("\nImportant Methodology Note:")
    print("- SHAP explanation time is NOT included in Model-Only or End-to-End scoring.")
    print("- In production, SHAP is called conditionally only when score >= threshold (~1.1% of transactions).")
    print("- When an alert IS raised, total execution time = End-to-End Scoring + TreeSHAP Explanation.")

    return {
        "model_only_prod": s_prod_mo,
        "model_only_cand": s_cand_mo,
        "e2e_prod": s_prod_e2e,
        "e2e_cand": s_cand_e2e,
        "shap_prod": s_prod_shap,
        "shap_cand": s_cand_shap,
    }


if __name__ == "__main__":
    benchmark()
