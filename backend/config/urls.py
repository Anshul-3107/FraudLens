import os

from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path


def health(request):
    return JsonResponse({"status": "ok", "service": "fraudlens-backend"})


ADMIN_URL_PATH = os.environ.get("DJANGO_ADMIN_URL", "admin/").lstrip("/")

urlpatterns = [
    path(ADMIN_URL_PATH, admin.site.urls),
    path("api/health/", health),
    path("api/", include("transactions.urls")),
]
