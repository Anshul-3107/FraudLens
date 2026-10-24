"""Security and CORS Middleware for FraudLens."""
from django.conf import settings
from django.http import HttpResponse


class SimpleCorsMiddleware:
    """Lightweight, zero-dependency CORS middleware.

    Activated when CORS_ALLOWED_ORIGINS or CORS_ALLOW_ALL_ORIGINS is configured.
    Handles OPTIONS preflight and sets standard CORS headers.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method == "OPTIONS" and "HTTP_ACCESS_CONTROL_REQUEST_METHOD" in request.META:
            response = HttpResponse()
            self._add_cors_headers(request, response)
            return response

        response = self.get_response(request)
        self._add_cors_headers(request, response)
        return response

    def _add_cors_headers(self, request, response):
        origin = request.META.get("HTTP_ORIGIN")
        if not origin:
            return

        allowed_origins = getattr(settings, "CORS_ALLOWED_ORIGINS", [])
        allow_all = getattr(settings, "CORS_ALLOW_ALL_ORIGINS", False)

        if allow_all or origin in allowed_origins:
            response["Access-Control-Allow-Origin"] = origin
            response["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            response["Access-Control-Allow-Headers"] = (
                "Accept, Authorization, Content-Type, Origin, X-CSRFToken, X-Requested-With"
            )
            response["Access-Control-Allow-Credentials"] = "true"
            response["Access-Control-Max-Age"] = "86400"
