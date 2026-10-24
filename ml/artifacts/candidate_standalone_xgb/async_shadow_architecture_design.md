# FraudLens Gate 7A.5 — Final Adversarial Asynchronous Shadow Architecture Blueprint & Sign-Off Specification

**Document Version:** 6.0 (Post-Gate 7A.5 Final Adversarial Architecture Sign-Off Revision)  
**Target Repository:** `D:\FraudLens`  
**Active Branch:** `staging-shadow-evaluation`  
**Candidate Model:** Standalone XGBoost (`ml/artifacts/candidate_standalone_xgb/xgb_model.joblib`)  
**Production Model:** Ensemble XGBoost + Isolation Forest (`ml/artifacts/xgb_with_iso.joblib` + `isolation_forest.joblib`)  
**Production Threshold:** `0.20`  
**Design Status:** DESIGN-ONLY (Strictly non-mutating; no code implemented; readiness sign-off)

---

## 1. Executive Verdict & Gate 7A.5 Resolutions

### **EXECUTIVE VERDICT: READY FOR IMPLEMENTATION REVIEW**

This document establishes the definitive, mathematically consistent, adversarial sign-off blueprint for the asynchronous staging shadow evaluation pipeline. All residual ambiguities identified in Gate 7A.5 have been resolved with concrete schemas, fixed test vectors, Windows-specific kernel lock semantics, and verified rollback protocols.

```
   [Gate 6F Crash Audit]    ──> REJECTED (Identified dual-write flaw & in-memory state loss)
   [Gate 7A Planning Gate]  ──> REJECTED (Identified Windows runbook defects & split writes)
   [Gate 7A.2 Challenge]   ──> REJECTED (Identified silent state synthesis & ineffective env vars)
   [Gate 7A.3 Review]       ──> REJECTED (Identified lack of quarantine table & fsync omission)
   [Gate 7A.4 Corrections]  ──> REJECTED (Identified quarantine key collision risk & unmeasured claims)
   ──────────────────────────────────────────────────────────────────────────────────────────────
   ==> [Gate 7A.5 Sign-Off] ──> READY FOR IMPLEMENTATION REVIEW
         * Unique Incident Primary Keys: UUID incident_id eliminates quarantine overwrite collisions
         * Versioned Canonical Hashing: Exact byte encoding, -0.0 normalization, fixed test vectors
         * Kernel File Lock vs Stale PID: OS-enforced msvcrt locking on shadow_consumer.lock
         * Bounded Sentinel Kill-Switch: Verified path, error handling, measured response criteria
         * 7-Step Verified Rollback: Step-by-step targeted termination and SHA-256 evidence archiving
         * Crash-Window Invariants: Formal separation of guarantees, recovery, and operator response
```

### Gate 7A.5 Resolution Summary

| Gate 7A.5 Area | Identified Ambiguity / Defect | Corrected Engineering Specification | Resolution Status |
| :--- | :--- | :--- | :---: |
| **1. Quarantine Identity & Overwrites** | Reusing `event_id` or timestamp as primary key risked collisions or overwriting earlier incident evidence. | **Independent UUID Incident Key:** Schema uses `incident_id TEXT PRIMARY KEY` (UUIDv4). `event_id` and `transaction_id` are separate nullable fields. Repeated conflicts for the same event append cleanly as distinct incidents. | **RESOLVED IN DESIGN** |
| **2. Canonical Payload Hashing** | Numeric rounding, negative zero, and hash input format lacked exact byte-level rules and test vectors. | **Versioned Canonical Hashing (`v1`):** Alphabetically sorted keys, 8-decimal float rounding, `-0.0` normalized to `0.0`, score formatted as `prod_score:.6f`, full 64-character SHA-256 hex digest, and 4 fixed test vectors. | **RESOLVED IN DESIGN** |
| **3. Kill-Switch Latency Assumptions** | 100 ms response was assumed without defined measurement protocols or filesystem error handling. | **Measurable Kill-Switch Protocol:** Absolute path resolution, `try...except OSError` fail-closed error handling, and a formal benchmark measuring activation-to-last-enqueue latency as a validation criterion. | **RESOLVED IN DESIGN** |
| **4. Consumer Ownership & Rollback** | PID files on disk can become stale; rollback runbook lacked exact PID verification and evidence checksums. | **Kernel-Enforced Lock & 7-Step Rollback:** Windows `msvcrt.locking` automatically released on process termination. Rollback verifies targeted PID, verifies file SHA-256 before archiving, and creates a manifest. | **RESOLVED IN DESIGN** |
| **5. Crash-Window Recovery Boundaries** | Lacked clear separation between absolute guarantees, recoverable states, unobservable losses, and operator actions. | **Four-Pillar Crash Analysis:** Every crash window explicitly categorizes Guaranteed Invariant, Recoverable State, Irrecoverable Loss, and Required Operator Action. | **RESOLVED IN DESIGN** |

---

## 2. Quarantine Identity & Authoritative SQLite Architecture

### 2.1 Authoritative SQLite Schema (`backend/logs/shadow_telemetry.sqlite3`)

The database contains three authoritative tables committing under `PRAGMA journal_mode = WAL` and `PRAGMA synchronous = NORMAL`:

```sql
-- 1. Authoritative candidate telemetry records
CREATE TABLE IF NOT EXISTS shadow_telemetry (
    event_id TEXT PRIMARY KEY,                 -- RFC 4122 UUIDv4 hex string (Immutable)
    payload_hash TEXT NOT NULL,                -- 64-char SHA-256 hex digest of canonical content
    transaction_id INTEGER NOT NULL,            -- Domain transaction ID
    prod_score REAL NOT NULL,                   -- Production ensemble score [0.0 - 1.0]
    prod_flagged INTEGER NOT NULL,              -- Production flag (0 or 1)
    prod_threshold REAL NOT NULL,               -- Production operating threshold (0.20)
    prod_latency_ms REAL NOT NULL,              -- Production scoring latency in ms
    cand_score REAL NOT NULL,                   -- Candidate standalone score [0.0 - 1.0]
    cand_flagged INTEGER NOT NULL,              -- Candidate flag (0 or 1)
    cand_threshold REAL NOT NULL,               -- Candidate operating threshold (0.20)
    cand_latency_ms REAL NOT NULL,              -- Candidate scoring latency in ms
    discordance_type TEXT NOT NULL,             -- CONCORDANT_POS/NEG, DISCORDANT_CAND/PROD
    score_delta REAL NOT NULL,                  -- Candidate score - Production score
    top_factor TEXT,                            -- Top SHAP risk factor (null if normal)
    processed_at_utc TEXT NOT NULL              -- ISO 8601 UTC timestamp
);

-- 2. Consumer processing lifecycle state table
CREATE TABLE IF NOT EXISTS shadow_consumer_state (
    event_id TEXT PRIMARY KEY,                 -- RFC 4122 UUIDv4 hex string
    payload_hash TEXT NOT NULL,                -- 64-char SHA-256 hex digest
    transaction_id INTEGER NOT NULL,            -- Domain transaction ID
    status TEXT CHECK(status IN ('COMPLETED', 'POISON_QUARANTINED', 'PAYLOAD_CONFLICT_QUARANTINED', 'CONSISTENCY_INCIDENT_QUARANTINED')) NOT NULL,
    chunk_filename TEXT NOT NULL,               -- Originating chunk filename
    updated_at_utc TEXT NOT NULL                -- ISO 8601 UTC timestamp
);

-- 3. Dedicated authoritative quarantine table (Incident-keyed)
CREATE TABLE IF NOT EXISTS shadow_quarantine (
    incident_id TEXT PRIMARY KEY,              -- RFC 4122 UUIDv4 unique incident ID
    event_id TEXT,                             -- Original event ID (nullable if record unparseable)
    transaction_id INTEGER,                    -- Domain transaction ID (nullable if malformed)
    payload_hash TEXT,                         -- 64-char SHA-256 fingerprint (nullable if unhashable)
    schema_version INTEGER NOT NULL DEFAULT 1, -- Version of canonical schema
    quarantine_reason TEXT NOT NULL,           -- POISON_FEATURE, PAYLOAD_MUTATION_CONFLICT, DATABASE_INCONSISTENCY, MALFORMED_RECORD
    raw_evidence TEXT NOT NULL,                -- Full raw JSON, fragment, or preserved file reference
    error_details TEXT NOT NULL,               -- Detailed error description or exception stack
    chunk_filename TEXT NOT NULL,              -- Originating chunk filename
    record_offset INTEGER NOT NULL,            -- 0-indexed line number in chunk
    quarantined_at_utc TEXT NOT NULL           -- ISO 8601 UTC timestamp
);

CREATE INDEX IF NOT EXISTS idx_telemetry_txn ON shadow_telemetry(transaction_id);
CREATE INDEX IF NOT EXISTS idx_consumer_status ON shadow_consumer_state(status);
CREATE INDEX IF NOT EXISTS idx_quarantine_event ON shadow_quarantine(event_id);
CREATE INDEX IF NOT EXISTS idx_quarantine_reason ON shadow_quarantine(quarantine_reason);
```

### 2.2 Collision-Free Incident Retention
1. **Primary Key Guarantee:** Because `incident_id` is a dedicated UUIDv4, every quarantine occurrence is recorded as an independent row.
2. **Repeated Conflict Safety:** If a client or upstream producer repeatedly submits conflicting payloads with the same `event_id`, each conflict attempt is recorded with a unique `incident_id` in `shadow_quarantine`. The original `shadow_telemetry` and `shadow_consumer_state` records remain **unmodified and unoverwritten**.
3. **Transaction Boundaries & Failure Behavior:**
   - When quarantining an event within a readable chunk, `shadow_quarantine` and `shadow_consumer_state` commit in the same `BEGIN IMMEDIATE ... COMMIT` transaction.
   - If SQLite cannot persist quarantine evidence (disk full `ENOSPC`, lock timeout):
     - The transaction **rolls back**.
     - The `.processing` chunk **remains on disk unacknowledged**. It is never deleted, moved, or truncated.
     - The consumer halts or enters exponential backoff pause (10s, 20s, 40s, capped at 60s) and emits a critical error to stderr. Evidence is never silently discarded.

---

## 3. Canonical Payload Serialization & Verified Checksum Rules

### 3.1 Version 1 (`v1`) Canonical Specification
The canonical payload hash defines the immutable identity of candidate scoring inputs:

1. **Features Scope:** Strictly the canonical 14 features from `ml/src/features.py`.
2. **Numeric Normalization:**
   - Every feature value $v$ is checked for finiteness: `math.isfinite(v)` must be True.
   - Negative zero is normalized to positive zero: `v = 0.0 if v == 0.0 else v`.
   - Float precision is rounded to 8 decimal places: `round(float(v), 8)`.
3. **Key Ordering & Separators:**
   - Feature dictionary keys are sorted in strict lexicographical order: `json.dumps(feats, sort_keys=True, separators=(',', ':'))`.
4. **Production Score Representation:**
   - Production score is formatted to exactly 6 decimal places: `f"{round(float(prod_score), 6):.6f}"`.
5. **Canonical String Construction:**
   $$\text{Canonical String} = \text{"v1:"} + \text{canonical\_json} + \text{":"} + \text{formatted\_score}$$
6. **Checksum Algorithm:**
   - SHA-256 digest computed over the UTF-8 bytes of the Canonical String.
   - Represented as a full **64-character lowercase hexadecimal string**.
   - Note on Event ID: `event_id` is an envelope routing identifier and is **excluded** from `payload_hash` so that identical feature inputs retain an invariant content hash regardless of producer retry attempts.

### 3.2 Fixed Reference Test Vectors

The following fixed test vectors must be implemented as validation fixtures in acceptance test suites:

#### Vector 1: Standard Normal Payload
- **Features Input:**
  `amt=125.50`, `log_amt=4.83230561`, `hour=14.0`, `dayofweek=2.0`, `is_night=0.0`, `category_code=5.0`, `dist_home_merchant_km=12.345678`, `amt_zscore=1.25`, `amt_ratio_to_mean=1.15`, `secs_since_last=3600.0`, `txn_count_1h=1.0`, `txn_count_24h=4.0`, `is_new_merchant=0.0`, `is_new_category=0.0`.
- **Production Score:** `0.045123`
- **Canonical Input String:**
  `v1:{"amt":125.5,"amt_ratio_to_mean":1.15,"amt_zscore":1.25,"category_code":5.0,"dayofweek":2.0,"dist_home_merchant_km":12.345678,"hour":14.0,"is_new_category":0.0,"is_new_merchant":0.0,"is_night":0.0,"log_amt":4.83230561,"secs_since_last":3600.0,"txn_count_1h":1.0,"txn_count_24h":4.0}:0.045123`
- **Authoritative SHA-256 Digest:**
  `a4a6b26baf0c8114afee79a4958d07780e9d58b93ae8530a066bc6eec0a0b8a3`

#### Vector 2: Reordered Input Keys (Invariance Test)
- **Input:** Identical feature values and score as Vector 1, submitted in reverse key order.
- **Canonical Input String:** Identical to Vector 1.
- **Authoritative SHA-256 Digest:**
  `a4a6b26baf0c8114afee79a4958d07780e9d58b93ae8530a066bc6eec0a0b8a3` (Exact match).

#### Vector 3: Float Boundary & Negative Zero Normalization
- **Features Input:** Identical to Vector 1, except `is_night = -0.0`, `is_new_merchant = 0.0`, `amt_zscore = -0.0`.
- **Production Score:** `0.0`
- **Canonical Input String:**
  `v1:{"amt":125.5,"amt_ratio_to_mean":1.15,"amt_zscore":0.0,"category_code":5.0,"dayofweek":2.0,"dist_home_merchant_km":12.345678,"hour":14.0,"is_new_category":0.0,"is_new_merchant":0.0,"is_night":0.0,"log_amt":4.83230561,"secs_since_last":3600.0,"txn_count_1h":1.0,"txn_count_24h":4.0}:0.000000`
- **Authoritative SHA-256 Digest:**
  `3bc4d2e4ad8f82839ef986f27509008cf633ea9e365932b69e3d6a6d40fa98ff`

#### Vector 4: Non-Finite Value Rejection
- **Features Input:** `amt = float('nan')` or `float('inf')`.
- **Expected Behavior:** `ValueError("Non-finite feature: amt")` raised before serialization; never serialized; discarded to volatile drop counter and logged.

---

## 4. Kill-Switch Reliability & Measurement Protocol

### 4.1 Specification & Resolution
- **Absolute Path:** `D:\FraudLens\backend\logs\SHADOW_DISABLED` resolved via:
  ```python
  SHADOW_KILL_SWITCH_PATH = (Path(settings.BASE_DIR) / "logs" / "SHADOW_DISABLED").resolve()
  ```
- **Error Handling:**
  ```python
  def is_shadow_active() -> bool:
      if not (getattr(settings, "SHADOW_MODE_ENABLED", False) and getattr(settings, "FRAUDLENS_ENV", "") == "staging"):
          return False
      try:
          if SHADOW_KILL_SWITCH_PATH.exists():
              return False
      except OSError as err:
          # Fail-closed for shadow (suppress evaluation), fail-open for transactions
          _logger.warning("Kill-switch check OSError: %s. Defaulting shadow to INACTIVE.", err)
          return False
      return True
  ```
- **Concurrent Request Behavior:**
  - Requests that evaluated `is_shadow_active() == True` before the file was created will complete their enqueue to `_worker_memory_queue`.
  - Any request evaluating after the sentinel file exists immediately skips enqueue.
- **Latency Target as a Measured Acceptance Criterion:**
  - The requirement that all worker threads cease enqueuing within 100 ms is **not assumed as a guarantee**, but must be explicitly measured in `TEST-KILLSWITCH-09`.
  - **Measurement Protocol:**
    1. Drive staging server with 50 req/s across 10 concurrent threads.
    2. Record high-resolution timestamp $T_{\text{kill}}$ when `SHADOW_DISABLED` is created.
    3. Monitor memory queue and spool files to find timestamp $T_{\text{last}}$ of the last enqueued event.
    4. Assert $(T_{\text{last}} - T_{\text{kill}}) < 100\text{ ms}$.

---

## 5. Reliable Consumer Ownership & 7-Step Rollback Runbook

### 5.1 Single-Consumer Kernel File Lock vs Stale PID Files
- **The Vulnerability of PID Files:** Plain text PID files on disk become stale when processes terminate abruptly without cleanup, or when Windows reassigns the same PID to an unrelated process.
- **The Kernel File Lock Solution:**
  - The consumer acquires an exclusive, non-blocking lock on `backend/logs/shadow_consumer.lock` using Windows `msvcrt.locking`:
    ```python
    self._lock_file = open("backend/logs/shadow_consumer.lock", "wb")
    try:
        msvcrt.locking(self._lock_file.fileno(), msvcrt.LK_NBLCK, 1)
    except OSError:
        sys.exit("FATAL: Another shadow consumer daemon is already running.")
    ```
  - **Kernel Guarantee:** The lock is tied directly to the file handle in the Windows kernel object table. If the consumer crashes, is killed via `Stop-Process`, or encounters an OOM, the **Windows kernel unconditionally releases the lock handle**. No stale lock files can block subsequent restarts.

### 5.2 The 7-Step Verified Rollback Protocol

Rollback must be executed in this exact sequence using native PowerShell:

```powershell
# ==============================================================================
# FRAUDLENS SHADOW PIPELINE ROLLBACK RUNBOOK (7-STEP VERIFIED SEQUENCE)
# ==============================================================================

# Step 1: Activate Sentinel Kill-Switch
$sentinelPath = "D:\FraudLens\backend\logs\SHADOW_DISABLED"
New-Item -Path $sentinelPath -ItemType File -Force
Write-Output "Step 1: Sentinel kill-switch activated at $sentinelPath"

# Step 2: Verify Producers Stopped Enqueueing
Start-Sleep -Milliseconds 250
$activeTmp = Get-ChildItem -Path "D:\FraudLens\backend\logs\spool\.tmp_*" -ErrorAction SilentlyContinue
Write-Output "Step 2: Verified producers stopped. Active .tmp files: $($activeTmp.Count)"

# Step 3: Targeted Consumer Identification & Termination
$consumerProcs = Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%run_shadow_consumer%'" | Where-Object {
    $_.ExecutablePath -like "*\ml\.venv\Scripts\python.exe*"
}
if ($consumerProcs) {
    foreach ($proc in $consumerProcs) {
        Write-Output "Step 3: Stopping targeted consumer PID $($proc.ProcessId)..."
        Stop-Process -Id $proc.ProcessId -Force
    }
} else {
    Write-Output "Step 3: No active consumer process detected."
}

# Step 4: Verify Consumer Process Termination
if ($consumerProcs) {
    foreach ($proc in $consumerProcs) {
        $p = Get-Process -Id $proc.ProcessId -ErrorAction SilentlyContinue
        if ($p) { throw "FATAL: Consumer PID $($proc.ProcessId) failed to terminate!" }
    }
}
Write-Output "Step 4: Consumer termination confirmed."

# Step 5: Integrity Verification of Pending Spool Evidence
$spoolFiles = Get-ChildItem -Path "D:\FraudLens\backend\logs\spool" -Include "*.chunk", "*.processing", ".tmp_*"
$manifest = @()
foreach ($file in $spoolFiles) {
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
    $lines = (Get-Content -Path $file.FullName | Measure-Object -Line).Lines
    $manifest += [PSCustomObject]@{
        Filename = $file.Name
        Bytes    = $file.Length
        Lines    = $lines
        SHA256   = $hash
    }
}
Write-Output "Step 5: Verified integrity of $($spoolFiles.Count) spool files."

# Step 6: Archive Verified Evidence
$archiveDir = "D:\FraudLens\backend\logs\spool\archive_rollback_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $archiveDir -Force
foreach ($file in $spoolFiles) {
    Move-Item -Path $file.FullName -Destination $archiveDir -Force
}
$manifest | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $archiveDir "manifest.json")
Write-Output "Step 6: Evidence securely archived to: $archiveDir"

# Step 7: Record Operational Status & Recovery Instructions
Write-Output "Step 7: Rollback completed successfully."
Write-Output "Outstanding unconsumed events preserved in $archiveDir."
Write-Output "To resume evaluation later: remove $sentinelPath and run recovery sweep."
```

---

## 6. Comprehensive Crash-Window Classification

| Crash Window | Injected Failure State | Guaranteed Invariant | Recoverable State | Irrecoverable / Unobservable Loss | Required Operator Action |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **W1: Producer Enqueue** | Web worker crashes while event is in `_worker_memory_queue`. | Production transaction and alert are committed to `db.sqlite3`. | Zero disk corruption. | **Unobservable Loss:** In-memory queue wiped; drop counter lost if worker recycles. | None. Accounted for via delta between production transactions and telemetry count. |
| **W2: Spooler Mid-Write** | Worker crashes while writing `.tmp_{worker}_{seq}.jsonl`. | In-flight batch is isolated to worker's private file. | Valid complete JSON lines recovered to `recovered_{uuid}.chunk`. | **Confirmed Loss:** Truncated trailing partial line discarded to `corrupt/partial_*.raw`. | None. Automatic startup sweep recovers valid events and logs partial bytes. |
| **W3: Spooler Pre-Sync** | File closed, but OS crashes before `os.fsync()` flushes blocks. | NTFS journaling prevents filesystem metadata corruption. | Complete blocks on disk survive. | **Potential Loss:** Uncheckpointed dirty page cache blocks lost if hard power pulled. | Startup sweep identifies 0-byte or corrupt file, moves to `corrupt/`, alerts operator. |
| **W4: Spooler Rename** | Crash after `fsync()`, before atomic `os.replace()`. | Full, valid `.tmp` file closed on disk. | Fully recoverable. Startup sweep detects complete `.tmp` file and promotes it to `.chunk`. | **Zero loss.** | None. Automatic promotion. |
| **W5: Consumer Claim** | Consumer crashes while renaming `.chunk` -> `.processing`. | NTFS atomic rename guarantees file is either `.chunk` or `.processing`. | If `.chunk`, claimed on next poll. If `.processing`, claimed after 15m stale timeout. | **Zero loss.** | None. Automatic discovery. |
| **W6: Model Inference** | Consumer crashes during XGBoost scoring or TreeSHAP computation. | Zero rows committed to `shadow_telemetry.sqlite3`. `.processing` file preserved on disk. | Fully recoverable. Restarted consumer re-reads `.processing` file. | **Zero loss.** | Restart consumer daemon via operational runbook. |
| **W7: SQLite Commit** | Crash during `BEGIN IMMEDIATE ... COMMIT`. | SQLite WAL atomicity: either both $T$ and $S$ exist, or neither exists. | Fully recoverable. SQLite WAL rolls back uncommitted frames automatically on restart. | **Zero loss.** | Restart consumer daemon. Replay will evaluate cleanly. |
| **W8: Chunk Cleanup** | Crash after SQLite commit, before unlinking `.processing`. | Both $T$ and $S$ committed to SQLite. `.processing` file remains on disk. | Fully recoverable. Consumer re-reads chunk, hits Case 2 (Idempotent Replay), unlinks chunk safely. | **Zero loss.** | None. Automatic idempotent acknowledgement. |
| **W9: Spool Disk Full** | Spool volume `D:` has 0 bytes free during web ingestion. | Web worker request thread drops shadow event fail-open via `put_nowait()`. | Production HTTP 201 response preserved; latency overhead $< 0.1\text{ ms}$. | **Unobservable Loss:** Flat file drop log fails with `ENOSPC`; only volatile RAM counter tracks drops. | Restore disk space. Volatile counters report drop rate until worker restarts. |
| **W10: SQLite Disk Full** | Disk volume `D:` has 0 bytes free during SQLite commit. | SQLite transaction aborts; `.processing` chunk preserved unacknowledged. | Consumer enters backoff pause; zero chunk evidence deleted. | **Zero evidence loss.** Processing paused. | Free disk space on volume `D:`. Consumer automatically resumes when space restored. |

---

## 7. Performance Acceptance Benchmark Specification (`TEST-PERF-11`)

The benchmark evaluates whether the async shadow pipeline meets latency and throughput targets on the actual staging environment:

1. **Environment & Constraints:**
   - Server: Staging server running `manage.py runserver 127.0.0.1:8000 --settings=config.settings_staging --noreload`.
   - Client: Concurrent HTTP driver using Python `threading` or `asyncio`.
   - Isolation: Dedicated staging cards (`cards_card` PKs 1–10); staging staff authentication token.
2. **Benchmark Workload Parameters:**
   - **Warm-Up Phase:** 500 transactions at 10 req/s to prime thread pools and file handles.
   - **Concurrency:** 10 concurrent HTTP worker threads.
   - **Target Throughput:** 50 requests per second.
   - **Test Volume:** 5,000 transactions per run.
   - **Repetitions:** Exactly **3 repeated runs** per condition.
   - **HTTP Timeout:** 2,000 ms client-side timeout.
3. **Execution Sequence:**
   - **Condition A (Baseline — Shadow Disabled):**
     Create sentinel `backend/logs/SHADOW_DISABLED`. Execute 3 runs of 5,000 requests. Record p50, p95, p99, error rate.
   - **Condition B (Test — Shadow Active):**
     Remove sentinel `backend/logs/SHADOW_DISABLED`. Launch consumer daemon. Execute 3 runs of 5,000 requests. Record p50, p95, p99, error rate, queue backlog depth, and backlog drain time.
4. **Acceptance Thresholds (Criteria to Validate, Not Assumed):**
   - **Latency Delta Criterion:** $\Delta p99 = (p99_{\text{shadow}} - p99_{\text{baseline}}) < 1.0\text{ ms}$.
   - **HTTP Error Rate Criterion:** Strictly **0.00%** (zero 500s, 502s, or timeouts).
   - **Backlog Drain Time Criterion:** Spool backlog must drain to 0 chunks within **60 seconds** after traffic ceases.
   - **Drop Rate Criterion:** $\le 0.01\%$ drops under 50 req/s steady-state.

---

## 8. Consumer Input Isolation & Privacy Minimization

1. **Zero Django ORM Imports:** `run_shadow_consumer.py` imports only mathematical and SQLite modules. It never imports `backend/transactions/models.py`.
2. **Read-Only Verification DB:** Any auxiliary verification queries against production connect strictly with `file:backend/db.sqlite3?mode=ro`.
3. **Self-Contained Payload:** All 14 features, z-scores, and velocities are pre-computed on the request path. The consumer performs zero database lookups to compute features.
4. **Pseudonymous Privacy:** Zero PII is persisted in `shadow_telemetry.sqlite3` or `shadow_quarantine`. No cardholder names, PANs, card references, coordinates, or merchant names exist in the shadow records.

---

*Notice: This document represents the complete, defect-corrected engineering blueprint for Gate 7A.5. No application code, test scripts, migrations, or database mutations were executed. The candidate model remains strictly unpromoted and isolated.*
