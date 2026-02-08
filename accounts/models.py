import uuid
from django.db import models
from django.utils import timezone
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
import hmac
import hashlib
import secrets
from django.conf import settings
from datetime import timedelta

class TimeStampModel(models.Model):
    uid = models.UUIDField(default=uuid.uuid4, unique=True, editable=False, db_index=True)
    created_at = models.DateTimeField(default=timezone.now, editable=False)
    updated_at = models.DateTimeField(default=timezone.now)

    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        self.updated_at = timezone.now()
        super().save(*args, **kwargs)


class AppUserManager(BaseUserManager):
    def create_user(self, username: str, password=None, **extra_fields):
        if not username:
            raise ValueError("username is required")

        user = self.model(username=username.strip().lower(), **extra_fields)

        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()

        user.save(using=self._db)
        return user

    def create_superuser(self, username: str, password=None, **extra_fields):
        extra_fields.setdefault("user_type", "INTERNAL_ADMIN")
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)

        
        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True")

        return self.create_user(username=username, password=password, **extra_fields)


class AppUser(AbstractBaseUser, PermissionsMixin, TimeStampModel):
    USER_TYPES = (
        ("OPERATOR", "Operator"),
        ("CLIENT_ADMIN", "Client Admin"),
        ("CLIENT_VIEWER", "Client Viewer"),
        ("INTERNAL_ADMIN", "Internal Admin"),
        ("EXAM_ADMIN", "Exam Admin"),
    )

    STATUSES = (
        ("ACTIVE", "Active"),
        ("BLACKLIST", "Blacklist"),
        ("INACTIVE", "Inactive"),
        ("ONBOARDING", "Onboarding"),
        ("PENDING_APPROVAL", "Pending Approval"),
        ("REJECTED", "Rejected"),
        ("REQUESTED", "Requested"),
    )

    username = models.CharField(max_length=150, unique=True)
    email = models.EmailField(max_length=150, null=True, blank=True)

    first_name = models.CharField(max_length=150, null=True, blank=True)
    middle_name = models.CharField(max_length=150, null=True, blank=True)
    last_name = models.CharField(max_length=150, null=True, blank=True)
    full_name = models.CharField(max_length=200, null=True, blank=True)

    user_type = models.CharField(max_length=30, choices=USER_TYPES, default="OPERATOR")
    status = models.CharField(max_length=30, choices=STATUSES, default="ACTIVE")
    
    # Optional link to a Client entity if this user is a Client Admin/Viewer
    client = models.ForeignKey('masters.Client', on_delete=models.SET_NULL, null=True, blank=True, related_name='users')
    
    # Optional link to an Exam entity if this user is an Exam Admin
    exam = models.ForeignKey('operations.Exam', on_delete=models.SET_NULL, null=True, blank=True, related_name='users')

    mobile_primary = models.CharField(max_length=10, null=True, blank=True)
    photo = models.ImageField(upload_to='user_photos/', null=True, blank=True)  # Store selfie after face match verification

    
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)

    objects = AppUserManager()

    USERNAME_FIELD = "username"
    REQUIRED_FIELDS = []

    def __str__(self):
        return f"{self.username} ({self.user_type})"

    def save(self, *args, **kwargs):
        
        # Sync is_active with status
        if self.status in ["BLACKLIST", "INACTIVE", "REJECTED"]:
            self.is_active = False
        elif self.status == "ACTIVE":
            self.is_active = True

        if not self.full_name:
            fn = (self.first_name or "").strip()
            mn = (self.middle_name or "").strip()
            ln = (self.last_name or "").strip()
            self.full_name = " ".join([x for x in [fn, mn, ln] if x]).strip() or None
        super().save(*args, **kwargs)






class OtpSession(models.Model):
    uid = models.UUIDField(default=uuid.uuid4, unique=True, editable=False, db_index=True)

    PURPOSES = (("OPERATOR_LOGIN", "Operator Login"),)
    purpose = models.CharField(max_length=30, choices=PURPOSES, default="OPERATOR_LOGIN")

    mobile = models.CharField(max_length=10, db_index=True)
    otp_hash = models.CharField(max_length=64)
    attempts = models.IntegerField(default=0)

    expires_at = models.DateTimeField(db_index=True)
    verified_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    @staticmethod
    def _hash_otp(mobile: str, otp: str) -> str:
        secret = settings.OTP_SECRET.encode("utf-8")
        msg = f"{mobile}:{otp}".encode("utf-8")
        return hmac.new(secret, msg, hashlib.sha256).hexdigest()

    @staticmethod
    def generate_otp() -> str:
        # 6-digit OTP (cryptographically secure)
        return str(secrets.randbelow(900000) + 100000)

    @staticmethod
    def default_expiry():
        return timezone.now() + timedelta(minutes=getattr(settings, "OTP_TTL_MINUTES", 5))

    def is_expired(self) -> bool:
        return timezone.now() >= self.expires_at