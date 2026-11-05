from django.contrib.auth.models import User  # noqa: F401  (keeps admin autodiscovery happy)
from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    AlertViewSet, CardViewSet, ExchangeRatesView, InvestigationViewSet,
    LinkBankAccountView, LoginView, LogoutView, MeView, RegisterView,
    SendOtpView, SummaryView, TransactionViewSet, VerifyOtpView,
)

router = DefaultRouter()
router.register("cards", CardViewSet, basename="card")
router.register("transactions", TransactionViewSet, basename="transaction")
router.register("alerts", AlertViewSet, basename="alert")
router.register("investigations", InvestigationViewSet, basename="investigation")

urlpatterns = [
    path("auth/register/", RegisterView.as_view()),
    path("auth/login/", LoginView.as_view()),
    path("auth/logout/", LogoutView.as_view()),
    path("auth/me/", MeView.as_view()),
    path("auth/phone/send-otp/", SendOtpView.as_view()),
    path("auth/phone/verify-otp/", VerifyOtpView.as_view()),
    path("accounts/link-bank/", LinkBankAccountView.as_view()),
    path("summary/", SummaryView.as_view()),
    path("exchange-rates/", ExchangeRatesView.as_view()),
    path("", include(router.urls)),
]