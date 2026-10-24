# FraudLens Gate 6B Preparation: Read-Only Shadow Feasibility Audit

**Target System:** `D:\FraudLens`  
**Active Branch:** `staging-shadow-evaluation`  
**Audit Date:** 2026-10-24  
**Audit Scope:** Production Shadow Evaluation Technical Feasibility & Architectural Blueprint  
**Candidate Model:** Standalone XGBoost (`ml/artifacts/candidate_standalone_xgb/xgb_model.joblib`)  
**Production Model:** Ensemble XGBoost + Isolation Forest (`ml/artifacts/xgb_with_iso.joblib` + `isolation_forest.joblib`)

---

## 1. Executive Outcome

### **OUTCOME: READY FOR SHADOW DESIGN**

A 48–72-hour production shadow evaluation of the standalone XGBoost candidate is **technically feasible and architecturally viable**, but is **NOT YET READY FOR IMMEDIATE LIVE PILOTING**.

```
   [Gate 5D Controlled Soak] ──> PASS (15/15 synthetic requests; isolated to staging)
   [Gate 6A Promotion Audit] ──> PASS (Ready for additional validation)
   ──────────────────────────────────────────────────────────────────────────────────
   [Gate 6B Feasibility]     ──> READY FOR SHADOW DESIGN
                                 * Architecture must decouple from synchronous request thread
                                 * Operational threshold selection must be finalized
                                 * Async queue and drift monitoring must be specified
```

**Key Justification:**
1. **Synchronous Hook Risk:** The existing shadow evaluation hook in `backend/transactions/ingest.py` is invoked synchronously on the HTTP request thread. Running this directly in production would add 12–35 ms of latency to every production transaction response and create worker thread contention.
2. **Candidate Robustness Verified:** The candidate model (14 canonical features, no `iso_score`, threshold 0.20) and dynamic TreeSHAP explainability (`ml/src/explain.py`) have passed 70/70 automated unit and integration tests with zero production database writes.
3. **Prerequisites Identified:** Transitioning to an active live pilot requires an asynchronous, durable event queue (out-of-process worker), a formal threshold sign-off (0.20 vs 0.14), and automated PSI/drift monitoring.

---

## 2. Production Request-Path Analysis

Inspection of `backend/transactions/views.py`, `backend/transactions/ingest.py`, and `backend/transactions/ml_service.py` reveals the exact production execution path:

```
[HTTP POST /api/transactions/]
        │
        ▼
[TransactionCreateSerializer] ── Validates schema (amount, coords, category, card ownership)
        │
        ▼
[ingest_transaction()]
        │
        ├── 1. Synchronous Production Scoring:
        │      score_transaction() -> compute_features() (14 features)
        │                          -> bundle.iso.score_samples() (iso_score)
        │                          -> bundle.model.predict_proba() (15 features)
        │                          -> explain.explain() if flagged
        │
        ├── 2. Atomic Database Commit:
        │      with db_transaction.atomic():
        │          txn = Transaction.objects.create(...)
        │          if flagged: Alert.objects.create(...)
        │
        └── 3. Current Shadow Hook (Post-Commit):
               shadow_evaluate_transaction()
                   │
                   └── _shadow_scorer.evaluate_shadow() [IN-PROCESS, SYNCHRONOUS]
```

### Critical Request-Path Findings:
- **Transaction Boundaries:** The database transaction `with db_transaction.atomic():` commits before shadow scoring is called. Therefore, candidate failures cannot roll back the transaction or alert record.
- **Synchronous Blocking Overhead:** While post-commit, `shadow_evaluate_transaction()` runs on the same web worker thread. The HTTP response is blocked until candidate scoring and telemetry append complete.
- **Thread Safety & Exception Isolation:** `evaluate_shadow()` traps all Python exceptions (`try...except Exception`) and writes error records. However, a fatal C-level extension failure (e.g., OpenMP segfault in XGBoost) would terminate the web worker process.
- **Architectural Requirement:** Production shadow scoring must be decoupled from the synchronous HTTP request-response cycle into an asynchronous worker.

---

## 3. Isolation & Privacy Audit

Inspection of `backend/transactions/shadow_service.py` and `backend/config/settings_staging.py` confirms existing safety controls:

1. **Gated Activation Condition:**
   - Shadow evaluation strictly requires `settings.FRAUDLENS_ENV == 'staging'` AND `settings.SHADOW_MODE_ENABLED is True`.
   - In production (`config.settings`), `FRAUDLENS_ENV` is not defined (or `"production"`), causing `shadow_evaluate_transaction()` to return immediately with `< 0.001 ms` overhead.
2. **Defensive Isolation:**
   - Uses `feats_copy = dict(features)`: the production feature dictionary is never mutated.
   - Performs **zero database operations**: no queries or writes to `backend/db.sqlite3` or any database.
3. **Feature Order & Schema Validation:**
   - Dynamically loads canonical features from `ml/src/features.py`.
   - Validates candidate booster feature names match canonical 14 features exactly.
   - Asserts `"iso_score"` is absent from candidate booster features.
   - Enforces finite float conversion (`np.all(np.isfinite(arr))`).
4. **Candidate Artifact & Threshold Guard:**
   - Standalone threshold is verified from `standalone_threshold.json` (`model_type == 'standalone_xgboost'`, `features_count == 14`).
   - Anti-fallback assertions in `settings_staging.py` prohibit pointing candidate paths to production artifacts.
5. **Pseudonymous Telemetry Privacy:**
   - Telemetry log (`shadow_eval.jsonl`) contains:
     - `timestamp_utc`, `transaction_id` (integer PK only)
     - `prod`: `{score, flagged, threshold, latency_ms}`
     - `candidate`: `{score, flagged, threshold, latency_ms, status, top_factor, error_type}`
     - `comparison`: `{score_delta, decision_agreement, discordance_type, latency_reduction_ms}`
   - **Zero PII Exposure:** No cardholder names, primary account numbers (PAN), card references, transaction references, coordinates, merchant names, amounts, or credentials exist in the telemetry record.

---

## 4. Proposed Production Shadow Architecture

To safely evaluate live production traffic without impacting production latency or reliability, an **asynchronous, out-of-band architecture** is proposed:

```
[Production Web Worker]
        │
        ├── Ingests, scores via Ensemble, and commits transaction
        │
        ├── Emits non-blocking event to buffer:
        │   {txn_id, canonical_features, prod_score, prod_flagged, prod_threshold, prod_latency_ms}
        │
        └── Returns HTTP 201 immediately to client (0 ms shadow latency added)
                 │
                 ▼
       [Durable Buffer / Queue] (e.g., Redis List, Celery, or append-only FIFO)
                 │
                 ▼
       [Isolated Shadow Worker Process] (Independent OS daemon)
                 │
                 ├── Reads event from queue
                 ├── Validates 14 canonical features
                 ├── Runs Candidate Standalone XGBoost inference
                 ├── Computes Candidate TreeSHAP if flagged
                 └── Appends pseudonymous record to `shadow_eval.jsonl`
```

### Failure Handling & Safeguards:
1. **Non-Blocking Ingestion:** Pushing to the queue must have a strict timeout (e.g. 2 ms). If the queue is unresponsive, the shadow event is dropped; production transaction ingestion never blocks.
2. **Queue Backpressure Limit:** If queue depth exceeds 5,000 unconsumed events, the ingestion hook temporarily drops shadow events until the worker catches up.
3. **Process Fault Isolation:** The shadow worker runs in a separate process/container. A worker crash or OOM has zero impact on the web server.
4. **Guaranteed Production Invariance:** The shadow worker process does not import Django database models and has no write credentials to `backend/db.sqlite3`.

---

## 5. 48–72-Hour Evaluation Design

### Minimum Sample-Size Rationale
- Elapsed time alone (48–72 hours) is insufficient if volume is low (e.g. over a bank holiday weekend).
- **Minimum Sample Requirement:** At least **20,000 production transactions** spanning at least two complete 24-hour business diurnal cycles.
- At an expected fraud prevalence of ~0.4%, 20,000 transactions will capture ~80 true fraud events, providing sufficient statistical power to observe real-world decision agreement and discordance.

### Privacy-Safe Aggregate Metrics

| Metric Dimension | Target Metric | Calculation / Granularity |
| :--- | :--- | :--- |
| **Volume & Completeness** | Eligible Volume | Count of transactions ingested vs shadow-scored |
| | Evaluation Error Rate | `%` of shadow inferences returning `ERROR` or `EXPLAIN_ERROR` |
| | Queue Backlog Depth | Gauge of unconsumed shadow events |
| **Decision Agreement** | Overall Decision Agreement | `(Both Flagged + Both Normal) / Total` (Target: > 95.0%) |
| | Concordant Normal Rate | Both models agree transaction is legitimate (`< 0.20`) |
| | Concordant Alert Rate | Both models agree transaction is suspicious (`>= 0.20`) |
| | Candidate-Only Alerts | Candidate flags (`>= 0.20`), Production does not |
| | Production-Only Alerts | Production flags (`>= 0.20`), Candidate does not |
| **Score Drift & Calibration** | Score Delta Distribution | `Score_cand - Score_prod` (p10, p25, p50, p75, p90, p99) |
| | Score Delta Trend | Rolling hourly mean and standard deviation of score delta |
| **Latency Comparison** | Request vs Scoring Latency | Production request latency vs Candidate scoring latency (p50, p95, p99) |
| **Cohort Breakdown** | Business Category Segments | Grouped by MCC category (`shopping_net`, `grocery_pos`, `travel`) |
| | Diurnal Day/Night Segments | Grouped by hour block (Day 06:00-22:00 vs Night 22:00-06:00) |
| | Distance Buckets | Local (< 50 km) vs Distant (> 200 km) |

---

## 6. Operational Abort Criteria (Provisional)

If any of the following conditions occur during the shadow run, the evaluation must be halted immediately:

| Category | Stop Condition | Provisional Threshold | Action |
| :--- | :--- | :---: | :--- |
| **Production Decision Mutation** | Any change to production transaction status, score, or alert | **> 0 occurrences** | **Immediate hard abort.** |
| **Database Contamination** | Any write to `backend/db.sqlite3` from shadow process | **> 0 occurrences** | **Immediate hard abort.** |
| **Privacy Breach** | PAN, cardholder name, password, or token in shadow log | **> 0 occurrences** | **Immediate abort;** purge log. |
| **Production Latency Impact** | Production API p95 latency increase over pre-shadow baseline | **> +15 ms or +15%** | **Immediate abort.** |
| **Decision Disagreement Surge** | Candidate disagreement rate on live traffic | **> 5.0%** sustained over 1,000 txns | Pause shadow run for review. |
| **Candidate Alert Volume Ratio** | Ratio of candidate alerts to production alerts | **> 1.25x (25% higher)** | Pause shadow run; check threshold. |
| **Candidate Scoring Failure** | Rate of candidate inference or explainer errors | **> 0.1% (1 in 1,000)** | Pause worker; investigate. |
| **Queue Backlog Overflow** | Unconsumed events in durable buffer | **> 5,000 items** | Suspend shadow queue push. |

*Note: Latency and volume thresholds are provisional and must be calibrated against verified production SLOs prior to launch.*

---

## 7. Monitoring & Rollback Readiness Assessment

### Current Capabilities vs Missing Operational Requirements

| Capability | Current Status | What Exists | What is Missing |
| :--- | :---: | :--- | :--- |
| **Isolated Model Loading** | **COMPLETE** | Schema validation for 14 features, anti-fallback assertions | None |
| **TreeSHAP Backward Compatibility** | **COMPLETE** | Dynamic factor grouping in `explain.py` | None |
| **Asynchronous Decoupling** | **MISSING** | Synchronous post-commit hook in `ingest.py` | Queue transport (Redis/Celery/FIFO) and daemon worker |
| **Population Stability Index (PSI)** | **MISSING** | Offline distribution statistics in report | Real-time PSI pipeline comparing live features to training set |
| **Real-Time Telemetry Dashboard** | **MISSING** | `shadow_eval.jsonl` local file rotation | Prometheus/Grafana or CloudWatch metrics exporter |
| **Tested Production Rollback** | **PARTIAL** | Code-level `FRAUDLENS_MODEL_MODE` switch & backups | Step-by-step production runbook with worker process restarts |
| **On-Call Escalation Runbook** | **MISSING** | Informal audit documentation | Formal ops runbook with designated engineer ownership |

---

## 8. Production Integrity Verification (Read-Only)

All production binary artifacts, thresholds, and SQLite tables were verified using non-mutating SHA-256 hashes and SQLite `mode=ro` connections:

```
Target File                             Size (bytes)   Current SHA-256                                                    Baseline Match
----------------------------------------------------------------------------------------------------------------------------------------
backend/db.sqlite3                      61,661,184     17d6d4e21b89386f4ef804e73cfe08ca3e26e687b71ad739fc8e5c91dd179146   MATCH
ml/artifacts/xgb_with_iso.joblib         3,946,708     b470ce023dc546876ac246de3f912c716e7db763e2d83b57d25ace49a58dd2b8   MATCH
ml/artifacts/isolation_forest.joblib     2,387,821     396fcee6c12d762d98e435aab185f2409616b95921d91990d539337a6093e769   MATCH
ml/artifacts/threshold.json                     47     aa37f1193b2edddfa063a011eb7865c92a3c1bb76064564e5b376f7f7f9e4604   MATCH
```

### Production Row Counts (`mode=ro`)
- `transactions_card`: **100** (Unchanged)
- `transactions_transaction`: **214,246** (Unchanged)
- `transactions_alert`: **707** (Unchanged)
- `auth_user`: **1** (Unchanged)

---

## 9. Explicitly Unverified Claims & Limitations

1. **Production Traffic Concurrency:** Staging soak evaluated sequential synthetic transactions; multi-threaded concurrent shadow inference on live multi-core servers remains unmeasured.
2. **Worker Restart Dynamics:** Changing model mode via environment variables requires a full application process restart (~2.9 s); in-flight workers do not detect OS env updates dynamically.
3. **Threshold Business Agreement:** Whether Fraud Operations approves Threshold `0.20` (+4.1% alerts) or Threshold `0.14` (+18.3% alerts) remains an open business policy decision.

---

## 10. Required Approvals Checklist Before Live Shadow Pilot

Prior to initiating any live shadow evaluation in production, the following formal approvals must be obtained:

- [ ] **Fraud Operations Leadership:** Written sign-off on operating threshold (`0.20` parity vs `0.14` high-recall).
- [ ] **Infrastructure & Engineering Architecture:** Approval of the asynchronous queue/worker decoupling design.
- [ ] **Security & Compliance:** Sign-off on pseudonymous shadow telemetry schema (`shadow_eval.jsonl`) verifying zero PII leakage.
- [ ] **Site Reliability Engineering (SRE):** Acceptance of provisional abort criteria, queue backpressure limits, and rolling restart procedures.
- [ ] **Production Rollback Verification:** Execution and documentation of a simulated rollback in staging under load.

---

*Notice: This audit was strictly read-only. The candidate remains unpromoted and isolated.*
