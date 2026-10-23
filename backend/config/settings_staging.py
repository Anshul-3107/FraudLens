"""Staging settings for FraudLens with isolated database and candidate artifacts.

Inherits from config.settings, with fail-closed safeguards:
1. Loads .env.staging before base settings evaluate environment variables.
2. Canonicalizes the staging database path and refuses to boot if it resolves
   or aliases to the production database (backend/db.sqlite3).
3. Configures isolated candidate standalone XGBoost artifact paths with zero
   fallback to production models or thresholds.
4. Gated shadow evaluation: requires FRAUDLENS_ENV == 'staging' and SHADOW_MODE_ENABLED.
"""
import os
import secrets
from pathlib import Path
from dotenv import load_dotenv
from django.core.exceptions import ImproperlyConfigured

# Step 1: Explicitly load .env.staging before base settings evaluate variables
BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env.staging", override=False)

# Step 2: Import base settings (will read already-populated os.environ)
from .settings import *  # noqa: F401, F403

# Step 3: Explicit staging environment marker
FRAUDLENS_ENV = "staging"

# Shadow mode is strictly disabled by default; requires explicit enablement
SHADOW_MODE_ENABLED = os.environ.get("SHADOW_MODE_ENABLED", "0").lower() in ("1", "true", "yes")

# Ephemeral secret key fallback if not provided in environment
if not os.environ.get("DJANGO_SECRET_KEY"):
    SECRET_KEY = secrets.token_urlsafe(48)

# Step 4: Strengthened SQLite Database Guard
raw_staging_db = os.environ.get("FRAUDLENS_STAGING_DB_PATH", str(BASE_DIR / "db_staging.sqlite3"))
staging_db_path = (BASE_DIR / raw_staging_db).resolve() if not Path(raw_staging_db).is_absolute() else Path(raw_staging_db).resolve()

resolved_staging = os.path.normcase(os.path.realpath(str(staging_db_path)))
resolved_prod = os.path.normcase(os.path.realpath(str(BASE_DIR / "db.sqlite3")))

# Reject identical canonical paths (accounts for symlinks, case-insensitivity, relative paths)
if resolved_staging == resolved_prod:
    raise ImproperlyConfigured(
        "\n====================================================================\n"
        "FATAL SAFETY GUARD TRIGGERED: Staging database path resolves to\n"
        f"the production database: {resolved_prod}\n"
        "Staging execution aborted to prevent production database mutation.\n"
        "Set FRAUDLENS_STAGING_DB_PATH to an isolated path (e.g. db_staging.sqlite3).\n"
        "===================================================================="
    )

# Reject hardlinks / same-file aliases if both files already exist
if os.path.exists(resolved_staging) and os.path.exists(resolved_prod):
    try:
        is_same = os.path.samefile(resolved_staging, resolved_prod)
    except OSError as err:
        raise ImproperlyConfigured(
            "\n====================================================================\n"
            "FATAL SAFETY GUARD TRIGGERED: Unexpected OS error while checking\n"
            f"database filesystem identity between staging and production: {err}\n"
            "Aborting execution to guarantee production database safety.\n"
            "===================================================================="
        ) from err

    if is_same:
        raise ImproperlyConfigured(
            "\n====================================================================\n"
            "FATAL SAFETY GUARD TRIGGERED: Staging database is a filesystem alias\n"
            f"or hardlink to the production database: {resolved_prod}\n"
            "Staging execution aborted.\n"
            "===================================================================="
        )

# Assign the validated canonical path to Django DATABASES
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": Path(resolved_staging),
    }
}

# Step 5: Candidate Artifact Standardization (Zero Fallback to Production)
ML_CANDIDATE_DIR = (BASE_DIR.parent / "ml" / "artifacts" / "candidate_standalone_xgb").resolve()
CANDIDATE_MODEL_PATH = (ML_CANDIDATE_DIR / "xgb_model.joblib").resolve()
CANDIDATE_THRESHOLD_PATH = (ML_CANDIDATE_DIR / "standalone_threshold.json").resolve()
CANDIDATE_EXPLAIN_PATH = (ML_CANDIDATE_DIR / "candidate_explain.py").resolve()

# Strict anti-fallback assertion: candidate artifacts must not point to production artifacts
prod_model = (ML_ARTIFACTS_DIR / "xgb_with_iso.joblib").resolve()
prod_thresh = (ML_ARTIFACTS_DIR / "threshold.json").resolve()

if os.path.normcase(str(CANDIDATE_MODEL_PATH)) == os.path.normcase(str(prod_model)):
    raise ImproperlyConfigured("Candidate model path cannot point to production xgb_with_iso.joblib")

if os.path.normcase(str(CANDIDATE_THRESHOLD_PATH)) == os.path.normcase(str(prod_thresh)):
    raise ImproperlyConfigured("Candidate threshold path cannot point to production threshold.json")

# Step 6: Telemetry Log Path
SHADOW_LOG_PATH = Path(os.environ.get("SHADOW_LOG_PATH", str(BASE_DIR / "logs" / "shadow_eval.jsonl"))).resolve()
