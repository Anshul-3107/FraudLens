"""Isolated Shadow-Mode Scoring Service for FraudLens Standalone XGBoost Candidate.

Safety Invariants:
1. Gated Execution: Only executes when FRAUDLENS_ENV == 'staging' and SHADOW_MODE_ENABLED is True.
2. Defensive Copy: Never mutates the caller's feature dictionary.
3. Isolated Artifacts: Loads strictly from candidate standalone XGBoost artifacts.
4. Total Containment: Traps and logs all exceptions; never raises to the caller.
5. Pseudonymous Telemetry: Zero PII, no card references, no coordinates, no raw amounts.
"""
import collections
import importlib.util
import json
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import sys
import time
from types import SimpleNamespace

from django.conf import settings
import joblib
import numpy as np
import pandas as pd

logger = logging.getLogger("transactions.shadow")


def _load_ml_module(module_name: str, file_path: Path):
    """Dynamically load an isolated module without modifying sys.path."""
    if module_name in sys.modules:
        return sys.modules[module_name]
    spec = importlib.util.spec_from_file_location(module_name, file_path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot load module {module_name} from {file_path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = mod
    spec.loader.exec_module(mod)
    return mod


class CandidateShadowScorer:
    """Safely evaluates the standalone XGBoost candidate model in shadow mode."""

    def __init__(self):
        self._bundle = None
        self._recent_txn_ids = collections.OrderedDict()  # LRU deduplication cache
        self._max_recent = 10000
        self._log_handler = None

    def get_bundle(self):
        if self._bundle is not None:
            return self._bundle

        model_path = getattr(settings, "CANDIDATE_MODEL_PATH", None)
        thresh_path = getattr(settings, "CANDIDATE_THRESHOLD_PATH", None)
        explain_path = getattr(settings, "CANDIDATE_EXPLAIN_PATH", None)

        if not model_path or not Path(model_path).is_file():
            raise FileNotFoundError(f"Missing candidate model artifact: {model_path}")
        if not thresh_path or not Path(thresh_path).is_file():
            raise FileNotFoundError(f"Missing candidate threshold artifact: {thresh_path}")
        if not explain_path or not Path(explain_path).is_file():
            raise FileNotFoundError(f"Missing candidate explain artifact: {explain_path}")

        # Safe dynamic loading of canonical features from ml/src
        ml_src = Path(settings.BASE_DIR).parent / "ml" / "src"
        ml_features = _load_ml_module("candidate_ml_features", ml_src / "features.py")
        canonical_features = list(ml_features.FEATURES)

        # Load candidate model & validate booster schema
        model = joblib.load(model_path)
        booster_features = list(model.get_booster().feature_names)
        if booster_features != canonical_features:
            raise ValueError(
                f"Candidate booster features mismatch!\n"
                f"Expected: {canonical_features}\nGot: {booster_features}"
            )
        if "iso_score" in booster_features:
            raise ValueError("Illegal feature 'iso_score' detected in standalone candidate booster!")

        # Load candidate threshold & validate schema
        thresh_data = json.loads(Path(thresh_path).read_text(encoding="utf-8"))
        if thresh_data.get("model_type") != "standalone_xgboost":
            raise ValueError(
                f"Candidate threshold model_type mismatch: expected 'standalone_xgboost', "
                f"got '{thresh_data.get('model_type')}'"
            )
        if thresh_data.get("features_count") != len(canonical_features):
            raise ValueError(
                f"Candidate threshold features_count mismatch: expected {len(canonical_features)}, "
                f"got '{thresh_data.get('features_count')}'"
            )
        threshold = float(thresh_data["threshold"])
        if not (0.0 <= threshold <= 1.0):
            raise ValueError(f"Candidate threshold outside [0, 1]: {threshold}")

        # Load isolated candidate explanation module
        cand_explain = _load_ml_module("candidate_explain", Path(explain_path))

        self._bundle = SimpleNamespace(
            model=model,
            explain=cand_explain,
            threshold=threshold,
            features_list=canonical_features,
        )
        return self._bundle

    def _setup_logger(self):
        if self._log_handler is not None:
            return
        log_path = getattr(settings, "SHADOW_LOG_PATH", None)
        if not log_path:
            return
        p = Path(log_path)
        p.parent.mkdir(parents=True, exist_ok=True)
        handler = RotatingFileHandler(
            str(p),
            maxBytes=20 * 1024 * 1024,  # 20 MB per file
            backupCount=5,              # 5 backups = max ~100MB
            encoding="utf-8",
        )
        handler.setFormatter(logging.Formatter("%(message)s"))
        self._log_handler = handler

    def evaluate_shadow(self, *, transaction_id, features, prod_result, prod_latency_ms):
        """Execute shadow candidate evaluation. Traps all exceptions; never raises."""
        # Pre-check: Deduplication
        if transaction_id in self._recent_txn_ids:
            return
        self._recent_txn_ids[transaction_id] = True
        if len(self._recent_txn_ids) > self._max_recent:
            self._recent_txn_ids.popitem(last=False)

        t0 = time.perf_counter()
        candidate_res = {
            "score": None,
            "flagged": None,
            "threshold": None,
            "latency_ms": None,
            "status": "UNKNOWN",
            "top_factor": None,
            "error_type": None,
        }

        try:
            # Defensive copy: Ensure caller's dictionary is never mutated
            feats_copy = dict(features)

            bundle = self.get_bundle()
            candidate_res["threshold"] = bundle.threshold

            # Input schema validation
            missing = [f for f in bundle.features_list if f not in feats_copy]
            if missing:
                raise ValueError(f"Missing canonical features: {missing}")

            canonical_vector = {f: feats_copy[f] for f in bundle.features_list}
            row_df = pd.DataFrame([canonical_vector])
            arr = row_df.to_numpy().astype(float)
            if not np.all(np.isfinite(arr)):
                raise ValueError("Non-finite values (NaN/Inf) detected in feature vector")

            # Candidate Model Inference
            score = float(bundle.model.predict_proba(row_df[bundle.features_list])[0, 1])
            if not np.isfinite(score) or not (0.0 <= score <= 1.0):
                raise ValueError(f"Invalid candidate prediction score: {score}")

            flagged = bool(score >= bundle.threshold)
            top_factor = None
            if flagged:
                try:
                    reasons = bundle.explain.explain_candidate(bundle.model, row_df)[0]
                    if reasons and isinstance(reasons, list) and len(reasons) > 0:
                        top_factor = reasons[0].get("factor")
                except Exception as expl_exc:
                    logger.warning("Shadow TreeSHAP exception on txn %s: %s", transaction_id, expl_exc)
                    candidate_res["status"] = "EXPLAIN_ERROR"
                    candidate_res["error_type"] = type(expl_exc).__name__

            if candidate_res["status"] != "EXPLAIN_ERROR":
                candidate_res["status"] = "SUCCESS"

            candidate_res.update({
                "score": round(score, 6),
                "flagged": flagged,
                "top_factor": top_factor,
            })

        except Exception as exc:
            candidate_res.update({
                "status": "ERROR",
                "error_type": type(exc).__name__,
            })
            logger.warning("Shadow candidate evaluation exception on txn %s: %s", transaction_id, exc)

        finally:
            candidate_res["latency_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
            self._write_telemetry_log(
                transaction_id=transaction_id,
                prod_result=prod_result,
                prod_latency_ms=prod_latency_ms,
                candidate_res=candidate_res,
            )

    def _write_telemetry_log(self, *, transaction_id, prod_result, prod_latency_ms, candidate_res):
        """Append pseudonymous telemetry record. Fails closed with zero exception leakage."""
        try:
            self._setup_logger()
            if not self._log_handler:
                return

            p_score = prod_result.get("score")
            p_flag = prod_result.get("flagged")
            c_score = candidate_res.get("score")
            c_flag = candidate_res.get("flagged")

            score_delta = round(c_score - p_score, 6) if (c_score is not None and p_score is not None) else None
            agreement = (p_flag == c_flag) if (c_flag is not None and p_flag is not None) else None

            if agreement is True:
                discordance = "CONCORDANT_POSITIVE" if p_flag else "CONCORDANT_NEGATIVE"
            elif agreement is False:
                discordance = "DISCORDANT_CAND_ONLY" if c_flag else "DISCORDANT_PROD_ONLY"
            else:
                discordance = "EVALUATION_ERROR"

            record = {
                "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "transaction_id": int(transaction_id),
                "prod": {
                    "score": round(p_score, 6) if p_score is not None else None,
                    "flagged": bool(p_flag) if p_flag is not None else None,
                    "threshold": prod_result.get("threshold"),
                    "latency_ms": round(float(prod_latency_ms), 3) if prod_latency_ms is not None else None,
                },
                "candidate": candidate_res,
                "comparison": {
                    "score_delta": score_delta,
                    "decision_agreement": agreement,
                    "discordance_type": discordance,
                    "latency_reduction_ms": round(float(prod_latency_ms) - candidate_res["latency_ms"], 3)
                    if (prod_latency_ms is not None and candidate_res.get("latency_ms") is not None) else None,
                },
            }
            record_str = json.dumps(record)
            self._log_handler.stream.write(record_str + "\n")
            self._log_handler.stream.flush()
        except (OSError, IOError) as io_exc:
            sys.stderr.write(f"[SHADOW_LOG_IO_ERROR] Failed to write shadow log for txn {transaction_id}: {io_exc}\n")
        except Exception as log_exc:
            sys.stderr.write(f"[SHADOW_LOG_ERROR] Unexpected logging error on txn {transaction_id}: {log_exc}\n")


_shadow_scorer = CandidateShadowScorer()


def shadow_evaluate_transaction(*, transaction_id, features, prod_result, prod_latency_ms):
    """Entrypoint for shadow evaluation. Fail-closed: returns immediately if not active."""
    is_staging = getattr(settings, "FRAUDLENS_ENV", None) == "staging"
    is_enabled = getattr(settings, "SHADOW_MODE_ENABLED", False) is True
    if not (is_staging and is_enabled):
        return

    try:
        _shadow_scorer.evaluate_shadow(
            transaction_id=transaction_id,
            features=features,
            prod_result=prod_result,
            prod_latency_ms=prod_latency_ms,
        )
    except Exception as exc:
        logger.warning(
            "Uncaught shadow evaluation boundary exception on txn %s: %s",
            transaction_id,
            exc,
        )

