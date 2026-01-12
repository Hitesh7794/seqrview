from django.urls import path
from .views import MeView, RegisterOperatorView, AdminCreateUserView,OperatorOtpRequestView, OperatorOtpVerifyView

urlpatterns = [
    path("me/", MeView.as_view()),

    path("register/", RegisterOperatorView.as_view()),

    path("admin/users/", AdminCreateUserView.as_view()),
    path("operator/otp/request/", OperatorOtpRequestView.as_view()),
    path("operator/otp/verify/", OperatorOtpVerifyView.as_view()),
]
