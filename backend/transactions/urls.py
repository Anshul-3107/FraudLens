from django.contrib.auth.models import User  # noqa: F401  (keeps admin autodiscovery happy)
from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    AlertViewSet, AvatarUploadView, CardViewSet, ExchangeRatesView, InvestigationViewSet,
    LinkBankAccountView, LoginView, LogoutView, MeView, RegisterView,
    RichieChatView, SummaryView, TransactionViewSet,
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
    path("auth/avatar/", AvatarUploadView.as_view()),
    path("accounts/link-bank/", LinkBankAccountView.as_view()),
    path("summary/", SummaryView.as_view()),
    path("exchange-rates/", ExchangeRatesView.as_view()),
    path("chat/richie/", RichieChatView.as_view()),
    path("", include(router.urls)),
]