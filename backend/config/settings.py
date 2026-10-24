import os
from pathlib import Path
import warnings

from django.core.exceptions import ImproperlyConfigured
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

# Environment & Debug Configuration
FRAUDLENS_ENV = os.environ.get(
    "FRAUDLENS_ENV",
    "development" if os.environ.get("DJANGO_DEBUG") in ("1", "true") else "production"
)
DEBUG = os.environ.get("DJANGO_DEBUG", "1" if FRAUDLENS_ENV == "development" else "0").lower() in ("1", "true", "yes")
IS_PRODUCTION = (not DEBUG) and (FRAUDLENS_ENV == "production")

# Secret Key Validation
DEFAULT_INSECURE_SECRET = "dev-only-insecure-key-change-me"
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", DEFAULT_INSECURE_SECRET if (DEBUG or FRAUDLENS_ENV != "production") else "")

# Allowed Hosts Validation
raw_allowed_hosts = os.environ.get("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1" if DEBUG else "")
ALLOWED_HOSTS = [h.strip() for h in raw_allowed_hosts.split(",") if h.strip()]


def validate_security_settings(secret_key, debug, allowed_hosts, is_production):
    """Enforces fail-closed configuration invariants for production environments."""
    if is_production:
        if debug:
            raise ImproperlyConfigured("DEBUG cannot be True in production deployment.")
        if not secret_key or secret_key == DEFAULT_INSECURE_SECRET:
            raise ImproperlyConfigured(
                "Cannot use insecure default SECRET_KEY in production deployment. A strong secret is required."
            )
        if len(secret_key) < 32:
            raise ImproperlyConfigured(
                "DJANGO_SECRET_KEY must be at least 32 characters long for production deployment."
            )
        if not allowed_hosts:
            raise ImproperlyConfigured("DJANGO_ALLOWED_HOSTS must be explicitly defined in production.")
        if "*" in allowed_hosts:
            raise ImproperlyConfigured("Wildcard '*' in ALLOWED_HOSTS is strictly prohibited in production.")


validate_security_settings(SECRET_KEY, DEBUG, ALLOWED_HOSTS, IS_PRODUCTION)

# CSRF Trusted Origins
raw_csrf_origins = os.environ.get("DJANGO_CSRF_TRUSTED_ORIGINS", "")
if raw_csrf_origins:
    CSRF_TRUSTED_ORIGINS = [o.strip() for o in raw_csrf_origins.split(",") if o.strip()]

# CORS Configuration
raw_cors_origins = os.environ.get("CORS_ALLOWED_ORIGINS", "")
CORS_ALLOWED_ORIGINS = [o.strip() for o in raw_cors_origins.split(",") if o.strip()]
CORS_ALLOW_ALL_ORIGINS = os.environ.get("CORS_ALLOW_ALL_ORIGINS", "0").lower() in ("1", "true", "yes")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework.authtoken",
    "transactions",
]

MIDDLEWARE = [
    "config.middleware.SimpleCorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

# Security Headers and Cookie Policy
if IS_PRODUCTION:
    SECURE_SSL_REDIRECT = os.environ.get("DJANGO_SECURE_SSL_REDIRECT", "1").lower() in ("1", "true", "yes")
    SESSION_COOKIE_SECURE = os.environ.get("DJANGO_SESSION_COOKIE_SECURE", "1").lower() in ("1", "true", "yes")
    CSRF_COOKIE_SECURE = os.environ.get("DJANGO_CSRF_COOKIE_SECURE", "1").lower() in ("1", "true", "yes")
    SECURE_HSTS_SECONDS = int(os.environ.get("DJANGO_SECURE_HSTS_SECONDS", "31536000"))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = os.environ.get("DJANGO_SECURE_HSTS_SUBDOMAINS", "1").lower() in ("1", "true", "yes")
    SECURE_HSTS_PRELOAD = os.environ.get("DJANGO_SECURE_HSTS_PRELOAD", "1").lower() in ("1", "true", "yes")
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = "DENY"
    SECURE_REFERRER_POLICY = "strict-origin-when-cross-origin"
    if os.environ.get("DJANGO_SECURE_PROXY_SSL_HEADER", "0").lower() in ("1", "true", "yes"):
        SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
else:
    SECURE_SSL_REDIRECT = False
    SESSION_COOKIE_SECURE = False
    CSRF_COOKIE_SECURE = False
    SECURE_HSTS_SECONDS = 0
    SECURE_HSTS_INCLUDE_SUBDOMAINS = False
    SECURE_HSTS_PRELOAD = False
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = "DENY"
    SECURE_REFERRER_POLICY = "strict-origin-when-cross-origin"

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

# Database Configuration
if os.environ.get("DB_ENGINE", "sqlite") == "postgres":
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.environ.get("DB_NAME", "fraudlens"),
            "USER": os.environ.get("DB_USER", "postgres"),
            "PASSWORD": os.environ.get("DB_PASSWORD", ""),
            "HOST": os.environ.get("DB_HOST", "localhost"),
            "PORT": os.environ.get("DB_PORT", "5432"),
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }
    if IS_PRODUCTION and os.environ.get("FRAUDLENS_ALLOW_SQLITE_PROD", "0") != "1":
        warnings.warn(
            "Production mode is running with SQLite. Set DB_ENGINE=postgres for production deployments.",
            RuntimeWarning,
            stacklevel=2,
        )

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.TokenAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 50,
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": os.environ.get("DJANGO_THROTTLE_ANON", "60/minute"),
        "user": os.environ.get("DJANGO_THROTTLE_USER", "300/minute"),
        "auth_register": os.environ.get("DJANGO_THROTTLE_AUTH_REGISTER", "10/minute"),
        "auth_login": os.environ.get("DJANGO_THROTTLE_AUTH_LOGIN", "20/minute"),
    },
    "EXCEPTION_HANDLER": "transactions.exceptions.custom_exception_handler",
}

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "[{asctime}] {levelname} [{name}:{lineno}] {message}",
            "style": "{",
        },
        "simple": {
            "format": "{levelname} {message}",
            "style": "{",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "verbose",
        },
    },
    "loggers": {
        "fraudlens.security": {
            "handlers": ["console"],
            "level": "INFO",
            "propagate": False,
        },
        "django.request": {
            "handlers": ["console"],
            "level": "ERROR",
            "propagate": False,
        },
    },
}

ML_ARTIFACTS_DIR = BASE_DIR.parent / "ml" / "artifacts"
ML_PROCESSED_DIR = BASE_DIR.parent / "ml" / "data" / "processed"