# FraudLens Standalone XGBoost: Shadow Evaluation Report

**Evaluation Date (UTC):** 2026-10-22T18:11:08.355656+00:00
**Target System:** FraudLens (`D:\FraudLens`)
**Evaluation Mode:** Read-Only Offline Shadow Benchmark

---

## 1. Executive Summary
This report presents an offline shadow evaluation comparing the current production ensemble (`xgb_with_iso.joblib` + `isolation_forest.joblib`) with the standalone candidate (`candidate_standalone_xgb/xgb_model.joblib`). All tests were performed read-only using existing processed data, without database modification or live scoring changes.

### Key Evaluation Findings
1. **Discrimination Equivalence:** On the held-out test partition (555,719 transactions), the standalone candidate matches production discrimination with **PR-AUC 0.8590** vs. **0.8589** and **ROC-AUC 0.9969** vs. **0.9971**.
2. **Operational Threshold Tradeoff:**
   - **Candidate at Validation Optimum (0.14):** Catches **16 more frauds** (94.17% vs 93.43% recall), reducing missed fraud losses by -$1,156.58. However, it increases alert volume by **+18.3% (+1,076 alerts)**, increasing review expense by +$5,380.00 at $5/alert (illustrative net cost: $52,515.26 vs. $48,291.84).
   - **Candidate at Operational Parity (0.20):** Catches **7 more frauds** (93.75% recall), alert volume increases by only **+4.1% (+243 alerts)**, and illustrative total cost is within **1.0% of production** ($48,792.53 vs. $48,291.84).
3. **Inference Efficiency:** Standalone XGBoost eliminates 200 Isolation Forest trees, reducing per-transaction scoring latency from **85.34ms** to **9.33ms** (median) and **108.06ms** to **10.51ms** (p95), and increasing bulk test throughput from **103,602 txn/s** to **651,258 txn/s**.
4. **Explainability Incompatibility:** Calling `explain.explain()` directly with the candidate model raises `KeyError: 'iso_score'` because `explain.py` hardcodes `"rarity": ["iso_score"]`. Removing the `rarity` grouping enables 100% clean TreeSHAP explanations based solely on canonical business features.

---

## 2. Model Performance Comparisons

### A. Validation Partition (271,832 rows, 1,607 frauds)
| Configuration | Threshold | PR-AUC | ROC-AUC | Brier Score | Log Loss | Recall | Precision | Specificity | Alerts | Missed Fraud Loss | Review Cost ($5/alert) | Total Illustrative Cost |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Production (`xgb_with_iso`)** | 0.200 | 0.9044 | 0.9984 | 0.003505 | 0.012830 | 95.27% | 42.85% | 99.24% | 3,573 | $8,974.65 | $17,865.00 | **$26,839.65** |
| **Production (`xgb_with_iso`)** | 0.207 | 0.9044 | 0.9984 | 0.003505 | 0.012830 | 95.21% | 43.26% | 99.26% | 3,537 | $8,994.09 | $17,685.00 | **$26,679.09** |
| **Candidate (Standalone XGB)** | 0.140 | 0.9031 | 0.9984 | 0.003589 | 0.013198 | 96.14% | 37.07% | 99.03% | 4,168 | $8,258.75 | $20,840.00 | **$29,098.75** |
| **Candidate (Standalone XGB)** | 0.200 | 0.9031 | 0.9984 | 0.003589 | 0.013198 | 95.02% | 41.43% | 99.20% | 3,686 | $13,210.94 | $18,430.00 | **$31,640.94** |

*Note: 0.207 is evaluated on validation strictly to verify the exact global minimum of the production model on validation data.*

### B. Held-Out Test Partition (555,719 rows, 2,145 frauds)
| Configuration | Threshold | PR-AUC | ROC-AUC | Brier Score | Log Loss | Recall | Precision | Specificity | Alerts | TP | FP | FN | Missed Fraud Loss | Review Cost ($5/alert) | Total Illustrative Cost |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Production Model** | 0.20 | 0.8589 | 0.9971 | 0.003221 | 0.011994 | 93.43% | 34.09% | 99.30% | 5,879 | 2,004 | 3,875 | 141 | $18,896.84 | $29,395.00 | **$48,291.84** |
| **Candidate Model** | 0.14 | 0.8590 | 0.9969 | 0.003328 | 0.012435 | 94.17% | 29.04% | 99.11% | 6,955 | 2,020 | 4,935 | 125 | $17,740.26 | $34,775.00 | **$52,515.26** |
| **Candidate Model** | 0.20 | 0.8590 | 0.9969 | 0.003328 | 0.012435 | 93.75% | 32.85% | 99.26% | 6,122 | 2,011 | 4,111 | 134 | $18,182.53 | $30,610.00 | **$48,792.53** |

---

## 3. Illustrative Business Cost Model & Assumptions

The cost model:
$$\text{Total Cost} = \sum_{i \in \text{FN}} \text{amount}_i + \$5.00 \times (\text{TP} + \text{FP})$$
is an **illustrative decision-support model**, not measured business savings.

### Critical Assumptions Requiring Stakeholder Alignment:
1. **Analyst Review Cost ($5.00/alert):** Assumes fixed review expense per flagged transaction. If investigation is automated (e.g. $1/alert via automated SMS push), Candidate @ 0.14 saves net money ($24,695 vs $24,775). If investigation is high-touch phone support ($20/alert), Candidate @ 0.14 adds +$20,363 in cost, heavily favoring threshold 0.20+.
2. **100% Unrecovered Loss on Missed Fraud:** Assumes 0% chargeback recovery or insurance reimbursement.
3. **100% Prevention on Flagged Transactions:** Assumes 0 leakage on flagged frauds.
4. **Zero Customer Churn Penalty for False Positives:** Assumes false alarms do not induce cardholder attrition.

---

## 4. Operational Latency & Throughput Benchmark

*Test Environment: Python 3.11.9 on Windows (AMD64), XGBoost 3.2.0, scikit-learn 1.9.1*

| Metric | Production Ensemble (`xgb_with_iso` + IF) | Standalone Candidate (`xgb_model`) | Operational Advantage |
| :--- | :---: | :---: | :--- |
| **Sequential Median Latency (batch=1)** | **85.343 ms** | **9.333 ms** | **89.1% faster** |
| **Sequential p95 Latency (batch=1)** | **108.063 ms** | **10.510 ms** | **90.3% faster** |
| **Sequential Mean Latency** | 89.105 ms | 9.457 ms | 89.4% faster |
| **Sequential Throughput** | 11.2 txn/s | 105.4 txn/s | +94.2 txn/s |
| **Bulk Scoring Time (555,719 rows)** | 5.36 s | 0.85 s | 4.51 s saved |
| **Bulk Scoring Throughput** | 103,602 txn/s | 651,258 txn/s | **+547,656 txn/s** |
| **Model Tree Count** | 1,182 trees (200 IF + 982 XGB) | 927 trees (927 XGB) | -255 trees (-21.6%) |
| **Artifact Footprint on Disk** | 6.33 MB (2 files) | 4.01 MB (1 file) | -2.32 MB (-36.7%) |

*Caveat: Offline inference latency benchmarks raw model prediction time. Real Django HTTP transaction requests incur additional database query and serialization overhead (approx 10-15ms).*

---

## 5. SHAP Explanation Compatibility Findings

### Direct Invocation Test
Calling `explain.explain(cand_xgb, sample_X)` directly raised:
```
KeyError: 'iso_score'
```
* **Root Cause:** In `ml/src/explain.py` lines 9-17:
  ```python
  GROUPS = {
      ...,
      "rarity": ["iso_score"],
  }
  ```
  Lines 102-106 map each feature in `GROUPS` to column indices in `booster.feature_names`. Because candidate has only 14 features and no `iso_score`, `idx["iso_score"]` throws `KeyError`.

### Required Integration Changes (Post-Promotion Plan):
1. **Modify `ml/src/explain.py`:**
   - Remove `"rarity": ["iso_score"]` from `GROUPS`.
   - Remove `"rarity": _rarity` from `TEXT`.
   - Optionally dynamically filter:
     `contribs[:, [idx[f] for f in GROUPS[g] if f in idx]].sum(axis=1)`
2. **Explainability Impact:** Eliminating `rarity` is an interpretability **improvement**. The candidate explains decisions entirely using intuitive factors: `amount`, `time`, `category`, `velocity`, `novelty`, and `location`.

---

## 6. Reproducibility & Safety Invariant Verification

| Invariant Item | Pre-Execution Value | Post-Execution Value | Status |
| :--- | :--- | :--- | :---: |
| `features.parquet` SHA-256 | `50f9c1eb81fe8c8b5fc8653b902f59cc7aa78678322142522e6e641195d50509` | `50f9c1eb81fe8c8b5fc8653b902f59cc7aa78678322142522e6e641195d50509` | **Identical** |
| `xgb_with_iso.joblib` SHA-256 | `b470ce023dc546876ac246de3f912c716e7db763e2d83b57d25ace49a58dd2b8` | `b470ce023dc546876ac246de3f912c716e7db763e2d83b57d25ace49a58dd2b8` | **Identical** |
| `isolation_forest.joblib` SHA-256| `396fcee6c12d762d98e435aab185f2409616b95921d91990d539337a6093e769` | `396fcee6c12d762d98e435aab185f2409616b95921d91990d539337a6093e769` | **Identical** |
| `threshold.json` (prod) SHA-256 | `aa37f1193b2edddfa063a011eb7865c92a3c1bb76064564e5b376f7f7f9e4604` | `aa37f1193b2edddfa063a011eb7865c92a3c1bb76064564e5b376f7f7f9e4604` | **Identical** |
| `xgb_model.joblib` (candidate) SHA-256| `44d991967a6e8290fb916f5f760b4e8241e4789426d3fe6947cd77158202d553` | `44d991967a6e8290fb916f5f760b4e8241e4789426d3fe6947cd77158202d553` | **Identical** |
| SQLite `transactions_transaction` | 214246 rows | 214246 rows | **Identical** |
| SQLite `transactions_alert` | 707 rows | 707 rows | **Identical** |
| SQLite `transactions_card` | 100 rows | 100 rows | **Identical** |
| SQLite `auth_user` | 1 rows | 1 rows | **Identical** |
| Production Threshold Value | `0.20` | `0.20` | **Identical** |

---

## 7. Limitations & Recommendations

1. **Do Not Automatically Promote:** Immediate promotion without operational alignment would force a choice between increasing alert volume by +18.3% (at threshold 0.14) or departing from the validation-selected threshold (at 0.20).
2. **Staged Promotion Recommendation:**
   - Convene a review with Fraud Operations leadership to select between **Threshold 0.20** (immediate drop-in replacement with parity workload) or **Threshold 0.14** (higher fraud catch rate with higher investigation volume).
   - Once threshold policy is selected, implement the single clean refactor in `ml/src/explain.py` and `backend/transactions/ml_service.py` to remove `isolation_forest`.
