from django.db import models
from django.conf import settings
from common.models import TimeStampedUUIDModel


class OperatorProfile(TimeStampedUUIDModel):
    PROFILE_STATUSES = (
        ("DRAFT", "Draft"),
        ("PROFILE_FILLED", "Profile Filled"),
        ("KYC_IN_PROGRESS", "KYC In Progress"),
        ("VERIFIED", "Verified"),
        ("REJECTED", "Rejected"),
    )

    KYC_METHODS = (
        ("NONE", "None"),
        ("AADHAAR", "Aadhaar"),
        ("DL", "Driving Licence"),
    )

    KYC_STATUSES = (
        ("NOT_STARTED", "Not Started"),
        ("OTP_SENT", "OTP Sent"),
        ("OTP_VERIFIED", "OTP Verified"),
        ("FACE_PENDING", "Face Pending"),
        ("VERIFIED", "Verified"),
        ("FAILED", "Failed"),
    )

    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="operator_profile")

    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=10, null=True, blank=True)

    current_address = models.CharField(max_length=255, null=True, blank=True)
    current_state = models.CharField(max_length=100, null=True, blank=True)
    current_zip = models.CharField(max_length=20, null=True, blank=True)
    current_district = models.CharField(max_length=100, null=True, blank=True)
    current_lat = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    current_lng = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)

    permanent_address = models.CharField(max_length=255, null=True, blank=True)
    permanent_state = models.CharField(max_length=100, null=True, blank=True)
    permanent_zip = models.CharField(max_length=20, null=True, blank=True)
    permanent_district = models.CharField(max_length=100, null=True, blank=True)

    profile_status = models.CharField(max_length=20, choices=PROFILE_STATUSES, default="DRAFT")
    verification_method = models.CharField(max_length=10, choices=KYC_METHODS, default="NONE")
    kyc_status = models.CharField(max_length=20, choices=KYC_STATUSES, default="NOT_STARTED")
    kyc_verified_at = models.DateTimeField(null=True, blank=True)
    kyc_fail_reason = models.CharField(max_length=255, null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["profile_status"]),
            models.Index(fields=["kyc_status"]),
        ]
