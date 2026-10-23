# FraudLens Standalone XGBoost Pre-Staging Audit Notes

## Date: 2026-10-23
## Target Model: Standalone XGBoost (`ml/artifacts/candidate_standalone_xgb/xgb_model.joblib`)

---

### 1. File Inspection Summary
- `candidate_service.py`: 180 lines, implements single-transaction scoring without Isolation Forest.
- `candidate_explain.py`: 150 lines, implements TreeSHAP factor attributions across 6 core factor groups without `rarity` or `iso_score`.
- `test_candidate_standalone.py`: 375 lines, 12 isolated unit tests covering schema, bounds, thresholds, extra features, invariance, and correlation.
- `benchmark_components.py`: 241 lines, symmetric 1,000-trial benchmark isolating model-only inference, end-to-end scoring, and conditional TreeSHAP.
- `standalone_threshold.json`: Schema containing `model_type: "standalone_xgboost"`, `features_count: 14`, `threshold: 0.20`.
- Proposed patches:
  - `0001_ml_service_standalone.patch`: Updates `backend/transactions/ml_service.py` with standalone loader and scoring.
  - `0002_candidate_explain_install.patch`: Installs standalone explainability as `ml/src/candidate_explain.py`.

---

### 2. Model / Threshold Pairing Verification
- **Independent Resolution:** Candidate model resolves to candidate directory or top-level `xgb_model.joblib`. Threshold resolves to candidate directory or top-level `standalone_threshold.json`.
- **Crosstalk Guardrails:**
  - Production `threshold.json` lacks `model_type == 'standalone_xgboost'` and `features_count == 14`. Any attempt to load it raises `ValueError`.
  - Production model `xgb_with_iso.joblib` has 15 features including `iso_score`. Any attempt to load it in candidate scoring raises `ValueError` with feature count mismatch.
- **Missing / Malformed Artifact Handling:**
  - Missing model file raises `FileNotFoundError`.
  - Missing threshold file raises `FileNotFoundError` (or config error).
  - Malformed JSON raises `ValueError` (wrapping `json.JSONDecodeError`).
  - Out-of-bounds threshold raises `ValueError`.

---

### 3. Patch Integrity (`git apply --check`)
- Command: `git apply --check ml/artifacts/candidate_standalone_xgb/proposed_patches/0001_ml_service_standalone.patch ml/artifacts/candidate_standalone_xgb/proposed_patches/0002_candidate_explain_install.patch`
- Result: Exit code 0 (Clean, 0 conflicts, 0 errors).

---

### 4. Benchmark Source & Computed Latency
- Input dataset: Held-out test partition (`features.parquet`), 1,000 identical rows.
- Warm-up trials: 50 iterations per pipeline.
- Timed repetitions: 1,000 iterations per pipeline.
- Timing boundaries:
  - Model-only scoring: Excludes feature dict extraction, excludes result dict construction, excludes SHAP.
  - End-to-End scoring (unflagged path, ~98.9% traffic): Includes dict extraction, DataFrame formation, inference, threshold comparison, result dict. Excludes SHAP.
  - TreeSHAP explanation: Evaluated separately on 50 flagged rows.
- Computed Results:
  - Model-Only: Prod Median 14.426 ms (p95 21.402 ms) vs. Candidate Median 1.880 ms (p95 2.760 ms) [-87.0%].
  - End-to-End: Prod Median 16.891 ms (p95 24.829 ms) vs. Candidate Median 2.955 ms (p95 4.212 ms) [-82.5%].
  - TreeSHAP: Prod Median 11.840 ms (p95 12.760 ms) vs. Candidate Median 11.244 ms (p95 12.110 ms) [-5.0%].

---

### 5. Candidate Tests & Production Regression
- Candidate Suite: 12/12 PASSED in 2.873s (`ml/artifacts/candidate_standalone_xgb/test_candidate_standalone.py`).
- Production Django Suite: 37/37 PASSED in 21.865s (`backend/manage.py test transactions`).

---

### 6. Working Tree Invariance
- Tracked production files modified: 0 (`git status --short`).
- SQLite DB row counts: identical before and after (transactions: 214,246, alerts: 707, cards: 100, auth_user: 1).
- Production artifact hashes: identical before and after.
