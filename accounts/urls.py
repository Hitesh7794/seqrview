from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import MeView, RegisterOperatorView, OperatorOtpRequestView, OperatorOtpVerifyView, AppUserViewSet

router = DefaultRouter()
router.register(r'users', AppUserViewSet, basename='users')

urlpatterns = [
    path("me/", MeView.as_view()),
    path("register/", RegisterOperatorView.as_view()),
    path("operator/otp/request/", OperatorOtpRequestView.as_view()),
    path("operator/otp/verify/", OperatorOtpVerifyView.as_view()),
    path("", include(router.urls)),
]
