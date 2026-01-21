from django.urls import path
from .views import (
    AadhaarKycStartView,
    AadhaarKycResendOtpView,
    AadhaarKycSubmitOtpView,
    AadhaarKycVerifyDetailsView,
    AadhaarKycResetView,
    DLKycStartView,
    DLKycVerifyDetailsView,
    FaceLivenessView,
    FaceMatchView,
)

urlpatterns = [
    path("aadhaar/start/", AadhaarKycStartView.as_view()),
    path("aadhaar/resend/", AadhaarKycResendOtpView.as_view()),
    path("aadhaar/submit-otp/", AadhaarKycSubmitOtpView.as_view()),
    path("aadhaar/verify-details/", AadhaarKycVerifyDetailsView.as_view()),
    path("aadhaar/reset/", AadhaarKycResetView.as_view()),
    path("dl/start/", DLKycStartView.as_view()),
    path("dl/verify-details/", DLKycVerifyDetailsView.as_view()),
    path("face/liveness/", FaceLivenessView.as_view()),
    path("face/match/", FaceMatchView.as_view()),
]
