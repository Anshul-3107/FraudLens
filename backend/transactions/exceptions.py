"""Security-hardened custom exception handler for FraudLens DRF API."""
import logging

from django.conf import settings
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import exception_handler

logger = logging.getLogger("fraudlens.security")


def custom_exception_handler(exc, context):
    """Sanitizes error responses to prevent internal information leakage in production.

    - Standard DRF exceptions (ValidationError, ParseError, NotAuthenticated, etc.)
      are formatted normally with appropriate status codes.
    - Unhandled internal server errors (500) log diagnostic tracebacks on the server,
      while returning a sanitized, structured JSON payload to clients without leaking
      internal database schema, SQL syntax, or filesystem paths.
    - In local development mode with DEBUG=True, returns None to allow Django's
      detailed technical traceback page for debugging.
    """
    response = exception_handler(exc, context)

    if response is not None:
        return response

    view = context.get("view")
    view_name = view.__class__.__name__ if view else "UnknownView"
    request = context.get("request")
    user = getattr(request, "user", None)
    username = getattr(user, "username", "Anonymous")

    logger.critical(
        "Unhandled exception in view %s by user %s: %s",
        view_name,
        username,
        exc,
        exc_info=True,
    )

    if not getattr(settings, "IS_PRODUCTION", False) or getattr(settings, "DEBUG", False):
        return None

    return Response(
        {
            "detail": "An internal server error occurred. This incident has been logged.",
            "error_code": "INTERNAL_SERVER_ERROR",
        },
        status=status.HTTP_500_INTERNAL_SERVER_ERROR,
    )
