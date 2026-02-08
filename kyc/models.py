import hmac
import hashlib
from datetime import timedelta
from django.db import models
from django.conf import settings
from django.utils import timezone
from common.models import TimeStampedUUIDModel


def default_kyc_expiry():
    return timezone.now() + timedelta(minutes=getattr(settings, "KYC_SESSION_TTL_MINUTES", 15))


class KycSession(TimeStampedUUIDModel):
    METHODS = (("AADHAAR", "Aadhaar"), ("DL", "Driving Licence"))
    STATUSES = (
        ("CREATED", "Created"),
        ("OTP_SENT", "OTP Sent"),
        ("OTP_VERIFIED", "OTP Verified"),
        ("DL_VERIFIED", "DL Verified"),
        ("DETAILS_VERIFIED", "Details Verified"),
        ("FAILED", "Failed"),
        ("COMPLETED", "Completed"),
        ("EXPIRED", "Expired"),
    )

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="kyc_sessions")
    method = models.CharField(max_length=10, choices=METHODS)
    status = models.CharField(max_length=20, choices=STATUSES, default="CREATED")

    surepass_client_id = models.CharField(max_length=220, null=True, blank=True)

    dedupe_hash = models.CharField(max_length=64, db_index=True)  
    otp_attempts = models.IntegerField(default=0)
    liveness_attempts = models.IntegerField(default=0)
    face_attempts = models.IntegerField(default=0)

    ekyc_full_name = models.CharField(max_length=255, null=True, blank=True)
    ekyc_dob = models.DateField(null=True, blank=True)
    ekyc_gender = models.CharField(max_length=10, null=True, blank=True)
    ekyc_address_data = models.JSONField(null=True, blank=True)

    name_match_score = models.FloatField(null=True, blank=True)
    name_match = models.BooleanField(null=True, blank=True)
    dob_match = models.BooleanField(null=True, blank=True)
    gender_match = models.BooleanField(null=True, blank=True)

    id_card_image_b64 = models.TextField(null=True, blank=True)

    vendor_reference_id = models.CharField(max_length=120, null=True, blank=True)
    vendor_uniqueness_id = models.CharField(max_length=120, null=True, blank=True)

    expires_at = models.DateTimeField(default=default_kyc_expiry, db_index=True)
    cleared_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "status"]),
            models.Index(fields=["dedupe_hash"]),
            models.Index(fields=["expires_at"]),
        ]

    def is_expired(self) -> bool:
        return timezone.now() >= self.expires_at

    def clear_sensitive(self):
        self.id_card_image_b64 = None
        self.cleared_at = timezone.now()
        self.save(update_fields=["id_card_image_b64", "cleared_at", "updated_at"])

    @staticmethod
    def compute_dedupe_hash(id_number: str) -> str:
        secret = settings.KYC_DEDUPE_SECRET.encode("utf-8")
        return hmac.new(secret, id_number.encode("utf-8"), hashlib.sha256).hexdigest()
    @staticmethod
    def default_expiry():
        minutes = getattr(settings, "KYC_SESSION_TTL_MINUTES", 10)
        return timezone.now() + timedelta(minutes=minutes)


class UserVerification(TimeStampedUUIDModel):
    METHODS = (("AADHAAR", "Aadhaar"), ("DL", "Driving Licence"))
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="verifications")

    method = models.CharField(max_length=10, choices=METHODS)
    verified = models.BooleanField(default=False)
    verified_at = models.DateTimeField(null=True, blank=True)

    name_match = models.BooleanField(null=True, blank=True)
    name_match_score = models.FloatField(null=True, blank=True)
    dob_match = models.BooleanField(null=True, blank=True)
    gender_match = models.BooleanField(null=True, blank=True)

    liveness_pass = models.BooleanField(null=True, blank=True)
    liveness_confidence = models.FloatField(null=True, blank=True)

    face_match_pass = models.BooleanField(null=True, blank=True)
    face_match_confidence = models.FloatField(null=True, blank=True)

    dedupe_hash = models.CharField(max_length=64, db_index=True)
    vendor_reference_id = models.CharField(max_length=120, null=True, blank=True)
    vendor_uniqueness_id = models.CharField(max_length=120, null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["method", "verified"]),
            models.Index(fields=["dedupe_hash"]),
        ]
