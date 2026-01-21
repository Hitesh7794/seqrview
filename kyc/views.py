import base64
from django.conf import settings
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from operators.models import OperatorProfile
from .models import KycSession, UserVerification
from .serializers import (
    AadhaarStartSerializer, AadhaarSubmitOtpSerializer, KycSessionUidSerializer, AadhaarVerifyDetailsSerializer,
    DLStartSerializer, DLVerifyDetailsSerializer
)
from .surepass_client import SurepassClient, SurepassError
from .match_utils import name_similarity


# Helpers
def _active_aadhaar_session(user):
   
    return (
        KycSession.objects.filter(
            user=user,
            method="AADHAAR",
            status__in=["CREATED", "OTP_SENT", "OTP_VERIFIED", "DETAILS_VERIFIED"],
        )
        .order_by("-created_at")
        .first()
    )


def _active_dl_session(user):
    
    return (
        KycSession.objects.filter(
            user=user,
            method="DL",
            status__in=["CREATED", "DL_VERIFIED", "DETAILS_VERIFIED"],
        )
        .order_by("-created_at")
        .first()
    )


# <----------------------------hitesh----------------------------------------->

class AadhaarKycResetView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.user_type != "OPERATOR":
            return Response({"detail": "Only operator can reset KYC"}, status=status.HTTP_403_FORBIDDEN)

        profile: OperatorProfile = request.user.operator_profile

        
        sess = (
            KycSession.objects.filter(
                user=request.user,
                method="AADHAAR",
                status__in=["CREATED", "OTP_SENT", "OTP_VERIFIED", "DETAILS_VERIFIED", "FAILED"],
            )
            .order_by("-created_at")
            .first()
        )
        if sess:
            sess.status = "EXPIRED"
            sess.save(update_fields=["status", "updated_at"])
            sess.clear_sensitive()

       
        if profile.profile_status != "VERIFIED":
            profile.profile_status = "PROFILE_FILLED"
        profile.kyc_status = "NOT_STARTED"
        profile.verification_method = "NONE"
        profile.kyc_fail_reason = None
        profile.save(
            update_fields=[
                "profile_status",
                "kyc_status",
                "verification_method",
                "kyc_fail_reason",
                "updated_at",
            ]
        )

        return Response({"reset": True})


class AadhaarKycStartView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.user_type != "OPERATOR":
            return Response({"detail": "Only operator can start KYC"}, status=status.HTTP_403_FORBIDDEN)

        ser = AadhaarStartSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        id_number = ser.validated_data["id_number"]

        profile: OperatorProfile = request.user.operator_profile

        cooldown_seconds = getattr(settings, "AADHAAR_OTP_COOLDOWN_SECONDS", 60)
        now = timezone.now()

       
        active = _active_aadhaar_session(request.user)
        if active and active.is_expired():
            active.status = "EXPIRED"
            active.save(update_fields=["status", "updated_at"])
            active = None

        if active:
            if active.status == "OTP_SENT":
                seconds_since = int((now - active.created_at).total_seconds())
                retry_after = max(0, cooldown_seconds - seconds_since)
                return Response(
                    {
                        "kyc_session_uid": str(active.uid),
                        "otp_sent": True,
                        "already_sent": True,
                        "retry_after_seconds": retry_after,
                        "expires_at": active.expires_at,
                        "status": active.status,
                    },
                    status=status.HTTP_200_OK,
                )
            return Response(
                {
                    "kyc_session_uid": str(active.uid),
                    "otp_sent": active.status != "CREATED",
                    "expires_at": active.expires_at,
                    "status": active.status,
                },
                status=status.HTTP_200_OK,
            )

        
        if profile.profile_status == "KYC_IN_PROGRESS" or profile.kyc_status == "FAILED":
            profile.profile_status = "DRAFT"
            profile.kyc_status = "NOT_STARTED"
            profile.verification_method = "NONE"
            profile.kyc_fail_reason = None
            profile.save(
                update_fields=[
                    "profile_status",
                    "kyc_status",
                    "verification_method",
                    "kyc_fail_reason",
                    "updated_at",
                ]
            )

        
        dedupe_hash = KycSession.compute_dedupe_hash(id_number)

        existing = (
            UserVerification.objects
            .filter(dedupe_hash=dedupe_hash, verified=True)
            .exclude(user=request.user)
            .first()
        )
        if existing:
            return Response({"detail": "This ID is already used for verification"}, status=status.HTTP_409_CONFLICT)

        
        client = SurepassClient()
        try:
            resp = client.aadhaar_generate_otp(id_number=id_number)
        except SurepassError as e:
            
            vendor_status = getattr(e, "status_code", None) or getattr(e, "http_status", None)
            msg = str(e)

            
            if vendor_status == 429 or "Rate Limited" in msg:
                return Response(
                    {
                        "detail": "Rate limited by Aadhaar provider. Please wait and try again.",
                        "code": "RATE_LIMITED",
                        "retry_after_seconds": cooldown_seconds,
                    },
                    status=status.HTTP_429_TOO_MANY_REQUESTS,
                )

            
            if vendor_status in (400, 401, 403):
                return Response({"detail": msg}, status=vendor_status)

            
            return Response({"detail": msg}, status=status.HTTP_502_BAD_GATEWAY)

       
        data = resp.get("data", {}) or {}
        surepass_client_id = data.get("client_id")

        session = KycSession.objects.create(
            user=request.user,
            method="AADHAAR",
            status="OTP_SENT",
            dedupe_hash=dedupe_hash,
            surepass_client_id=surepass_client_id,
            expires_at=KycSession.default_expiry(),   
        )

        profile.profile_status = "KYC_IN_PROGRESS"
        profile.verification_method = "AADHAAR"
        profile.kyc_status = "OTP_SENT"
        profile.kyc_fail_reason = None
        profile.save(update_fields=[
            "profile_status", "verification_method", "kyc_status", "kyc_fail_reason", "updated_at"
        ])

        return Response({
            "kyc_session_uid": str(session.uid),
            "otp_sent": bool(data.get("otp_sent", True)),
            "already_sent": False,
            "expires_at": session.expires_at,
            "status": "OTP_SENT",
        }, status=status.HTTP_200_OK)


class AadhaarKycResendOtpView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.user_type != "OPERATOR":
            return Response({"detail": "Only operator can resend KYC OTP"}, status=status.HTTP_403_FORBIDDEN)

        # Expect id_number to be passed to regenerate OTP
        ser = AadhaarStartSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        id_number = ser.validated_data["id_number"]

        cooldown_seconds = getattr(settings, "AADHAAR_OTP_COOLDOWN_SECONDS", 60)
        now = timezone.now()

        active = _active_aadhaar_session(request.user)
        if not active:
            return Response({"detail": "No active session found. Please start new verification."}, status=status.HTTP_404_NOT_FOUND)

        if active.is_expired():
            active.status = "EXPIRED"
            active.save(update_fields=["status", "updated_at"])
            return Response({"detail": "Session expired. Please start again."}, status=status.HTTP_400_BAD_REQUEST)

        # Check cooldown (using updated_at which tracks last interaction)
        seconds_since = int((now - active.updated_at).total_seconds())
        if seconds_since < cooldown_seconds:
            retry_after = max(0, cooldown_seconds - seconds_since)
            return Response(
                {
                    "detail": f"Please wait {retry_after}s before resending",
                    "retry_after_seconds": retry_after,
                },
                status=status.HTTP_429_TOO_MANY_REQUESTS
            )

        # Verify ID matches the one used for dedupe (sanity check)
        dedupe_hash = KycSession.compute_dedupe_hash(id_number)
        if active.dedupe_hash != dedupe_hash:
             return Response({"detail": "Aadhaar number does not match active session"}, status=status.HTTP_400_BAD_REQUEST)

        client = SurepassClient()
        try:
            resp = client.aadhaar_generate_otp(id_number=id_number)
        except SurepassError as e:
            vendor_status = getattr(e, "status_code", None) or getattr(e, "http_status", None)
            msg = str(e)
            if vendor_status == 429 or "Rate Limited" in msg:
                return Response(
                    {
                        "detail": "Rate limited by Aadhaar provider. Please wait.",
                        "code": "RATE_LIMITED",
                        "retry_after_seconds": cooldown_seconds,
                    },
                    status=status.HTTP_429_TOO_MANY_REQUESTS,
                )
            return Response({"detail": msg}, status=status.HTTP_502_BAD_GATEWAY)

        data = resp.get("data", {}) or {}
        surepass_client_id = data.get("client_id")

        if surepass_client_id:
            active.surepass_client_id = surepass_client_id
        
        active.status = "OTP_SENT"
        active.otp_attempts = 0 # Reset attempts
        active.updated_at = now
        active.save(update_fields=["surepass_client_id", "status", "otp_attempts", "updated_at"])

        return Response({
            "kyc_session_uid": str(active.uid),
            "otp_sent": True,
            "retry_after_seconds": cooldown_seconds,
            "status": "OTP_SENT"
        }, status=status.HTTP_200_OK)


class AadhaarKycSubmitOtpView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.user_type != "OPERATOR":
            return Response({"detail": "Only operator"}, status=status.HTTP_403_FORBIDDEN)

        ser = AadhaarSubmitOtpSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        session_uid = ser.validated_data["kyc_session_uid"]
        otp = ser.validated_data["otp"]

        session = KycSession.objects.filter(uid=session_uid, user=request.user).first()
        if not session:
            return Response({"detail": "Invalid KYC session"}, status=status.HTTP_404_NOT_FOUND)

        if session.is_expired():
            session.status = "EXPIRED"
            session.save(update_fields=["status", "updated_at"])
            return Response({"detail": "Session expired"}, status=status.HTTP_400_BAD_REQUEST)

        
        if session.status == "FAILED" and session.otp_attempts < 3:
            session.status = "OTP_SENT"
            session.save(update_fields=["status", "updated_at"])
        elif session.status != "OTP_SENT":
            
            if session.status == "FAILED" and session.otp_attempts >= 3:
                profile: OperatorProfile = request.user.operator_profile
                profile.kyc_status = "FAILED"
                profile.kyc_fail_reason = "OTP attempts exceeded"
                profile.save(update_fields=["kyc_status", "kyc_fail_reason", "updated_at"])
                return Response({
                    "detail": "OTP attempts exceeded. Please restart KYC.",
                    "code": "RESTART_REQUIRED"
                }, status=status.HTTP_400_BAD_REQUEST)
            return Response({"detail": f"Invalid state: {session.status}"}, status=status.HTTP_400_BAD_REQUEST)

        if session.otp_attempts >= 3:
            
            profile: OperatorProfile = request.user.operator_profile
            profile.kyc_status = "FAILED"
            profile.kyc_fail_reason = "OTP attempts exceeded"
            profile.save(update_fields=["kyc_status", "kyc_fail_reason", "updated_at"])
            session.status = "FAILED"
            session.save(update_fields=["status", "updated_at"])
            return Response({
                "detail": "OTP attempts exceeded. Please restart KYC.",
                "code": "RESTART_REQUIRED"
            }, status=status.HTTP_429_TOO_MANY_REQUESTS)

        session.otp_attempts += 1
        session.save(update_fields=["otp_attempts", "updated_at"])

        profile: OperatorProfile = request.user.operator_profile

        client = SurepassClient()
        try:
            resp = client.aadhaar_submit_otp(client_id=session.surepass_client_id, otp=otp)
        except SurepassError as e:
            
            if session.otp_attempts >= 3:
                session.status = "FAILED"
                session.save(update_fields=["status", "updated_at"])

                profile.kyc_status = "FAILED"
                reason = str(e)[:250]
                profile.kyc_fail_reason = reason
                profile.save(update_fields=["kyc_status", "kyc_fail_reason", "updated_at"])
            else:
                
                profile.kyc_status = "OTP_SENT"
                profile.kyc_fail_reason = None
                profile.save(update_fields=["kyc_status", "kyc_fail_reason", "updated_at"])

            if getattr(e, "status_code", None) == 429:
                return Response(
                    {"detail": str(e), "code": "RATE_LIMITED", "retry_after_seconds": 60},
                    status=status.HTTP_429_TOO_MANY_REQUESTS
                )

            if getattr(e, "status_code", None) in (400, 401, 403):
                return Response({"detail": str(e)}, status=e.status_code)

            return Response({"detail": str(e)}, status=status.HTTP_502_BAD_GATEWAY)

        data = resp.get("data", {}) or {}

        ekyc_name = data.get("full_name") or ""
        ekyc_gender = (data.get("gender") or "").strip()
        dob_str = data.get("dob")

        ekyc_dob = None
        if dob_str:
            try:
                ekyc_dob = timezone.datetime.fromisoformat(dob_str).date()
            except ValueError:
                ekyc_dob = None

        img_b64 = data.get("profile_image") if data.get("has_image") else None

        
        session.ekyc_full_name = ekyc_name
        session.ekyc_gender = ekyc_gender
        session.ekyc_dob = ekyc_dob
        session.vendor_reference_id = data.get("reference_id")
        session.vendor_uniqueness_id = data.get("uniqueness_id")
        session.id_card_image_b64 = img_b64
        session.status = "OTP_VERIFIED"
        session.save(update_fields=[
            "ekyc_full_name", "ekyc_gender", "ekyc_dob",
            "vendor_reference_id", "vendor_uniqueness_id", "id_card_image_b64",
            "status", "updated_at"
        ])

        profile: OperatorProfile = request.user.operator_profile
        profile.kyc_status = "OTP_VERIFIED"
        profile.kyc_fail_reason = None
        profile.save(update_fields=["kyc_status", "kyc_fail_reason", "updated_at"])

        
        return Response({
            "status": "OTP_VERIFIED",
            "next": "VERIFY_DETAILS",
            "aadhaar_details": {
                "full_name": ekyc_name,
                "date_of_birth": str(ekyc_dob) if ekyc_dob else None,
                "gender": ekyc_gender,
            }
        })


class AadhaarKycVerifyDetailsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.user_type != "OPERATOR":
            return Response({"detail": "Only operator"}, status=status.HTTP_403_FORBIDDEN)

        ser = AadhaarVerifyDetailsSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        session_uid = ser.validated_data["kyc_session_uid"]
        user_full_name = (ser.validated_data.get("full_name") or "").strip()
        user_dob = ser.validated_data.get("date_of_birth")
        user_gender = (ser.validated_data.get("gender") or "").strip()
        user_state = (ser.validated_data.get("state") or "").strip()
        user_district = (ser.validated_data.get("district") or "").strip()
        user_address = (ser.validated_data.get("address") or "").strip()

        session = KycSession.objects.filter(uid=session_uid, user=request.user).first()
        if not session:
            return Response({"detail": "Invalid KYC session"}, status=status.HTTP_404_NOT_FOUND)

        if session.is_expired():
            session.status = "EXPIRED"
            session.save(update_fields=["status", "updated_at"])
            return Response({"detail": "Session expired"}, status=status.HTTP_400_BAD_REQUEST)

        # Allow from OTP_VERIFIED (Aadhaar) or DL_VERIFIED (DL)
        if session.status not in ["OTP_VERIFIED", "DL_VERIFIED"]:
            return Response({"detail": f"Invalid state: {session.status}"}, status=status.HTTP_400_BAD_REQUEST)

        
        ekyc_name = (session.ekyc_full_name or "").strip()
        ekyc_dob = session.ekyc_dob
        ekyc_gender = (session.ekyc_gender or "").strip()

        # Exact name matching (case-insensitive, normalized whitespace)
        user_name_normalized = " ".join(user_full_name.split()) if user_full_name else ""
        ekyc_name_normalized = " ".join(ekyc_name.split()) if ekyc_name else ""
        name_ok = bool(user_name_normalized.upper() == ekyc_name_normalized.upper())
        score = 1.0 if name_ok else 0.0  # Store 1.0 for exact match, 0.0 for mismatch
        
        dob_ok = bool(user_dob is not None and ekyc_dob is not None and user_dob == ekyc_dob)
        gender_ok = bool(user_gender and ekyc_gender and user_gender.upper() == ekyc_gender.upper())

        
        session.name_match_score = score
        session.name_match = name_ok
        session.dob_match = dob_ok
        session.gender_match = gender_ok

        profile: OperatorProfile = request.user.operator_profile

        if name_ok and dob_ok and gender_ok:
            
            if user_full_name:
                name_parts = user_full_name.split(maxsplit=2)
                request.user.first_name = name_parts[0] if len(name_parts) > 0 else ""
                request.user.last_name = name_parts[-1] if len(name_parts) > 1 else ""
                request.user.middle_name = name_parts[1] if len(name_parts) > 2 else ""
                request.user.full_name = user_full_name
                request.user.save(update_fields=["first_name", "middle_name", "last_name", "full_name", "updated_at"])

            
            profile.date_of_birth = user_dob
            profile.gender = user_gender
            profile.current_state = user_state if user_state else None
            profile.current_district = user_district if user_district else None
            profile.current_address = user_address if user_address else None
            profile.profile_status = "KYC_IN_PROGRESS"
            profile.kyc_status = "FACE_PENDING"  
            profile.kyc_fail_reason = None
            profile.save(update_fields=[
                "date_of_birth", "gender", "current_state", "current_district", "current_address",
                "profile_status", "kyc_status", "kyc_fail_reason", "updated_at"
            ])

         
            session.status = "DETAILS_VERIFIED"
            session.save(update_fields=[
                "name_match_score", "name_match", "dob_match", "gender_match",
                "status", "updated_at"
            ])

            return Response({
                "status": "DETAILS_VERIFIED",
                "next": "FACE_LIVENESS",
                "match": True
            })
        else:
            # Mismatch - allow retry
            session.save(update_fields=[
                "name_match_score", "name_match", "dob_match", "gender_match",
                "updated_at"
            ])

            # Keep current status for retry
            current_status = session.status
            profile.kyc_status = current_status if current_status in ["OTP_VERIFIED", "DL_VERIFIED"] else "OTP_VERIFIED"
            profile.kyc_fail_reason = "Details mismatch"
            profile.save(update_fields=["kyc_status", "kyc_fail_reason", "updated_at"])

            return Response({
                "status": current_status,
                "match": False,
                "mismatches": {
                    "name": not name_ok,
                    "date_of_birth": not dob_ok,
                    "gender": not gender_ok,
                },
                "name_match_score": score,
                "message": f"Details do not match {session.get_method_display()}. Please verify and try again."
            }, status=status.HTTP_400_BAD_REQUEST)


class DLKycStartView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.user_type != "OPERATOR":
            return Response({"detail": "Only operator can start KYC"}, status=status.HTTP_403_FORBIDDEN)

        ser = DLStartSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        license_number = ser.validated_data["license_number"].strip().upper()
        dob = ser.validated_data["dob"]

        profile: OperatorProfile = request.user.operator_profile

        # Check for active DL session
        active = _active_dl_session(request.user)
        if active and active.is_expired():
            active.status = "EXPIRED"
            active.save(update_fields=["status", "updated_at"])
            active = None

        if active:
            return Response(
                {
                    "kyc_session_uid": str(active.uid),
                    "expires_at": active.expires_at,
                    "status": active.status,
                },
                status=status.HTTP_200_OK,
            )

        # If profile is stuck in-progress or failed but no active session is present, reset to allow restart.
        if profile.profile_status == "KYC_IN_PROGRESS" or profile.kyc_status == "FAILED":
            profile.profile_status = "DRAFT"
            profile.kyc_status = "NOT_STARTED"
            profile.verification_method = "NONE"
            profile.kyc_fail_reason = None
            profile.save(
                update_fields=[
                    "profile_status",
                    "kyc_status",
                    "verification_method",
                    "kyc_fail_reason",
                    "updated_at",
                ]
            )

        # Dedupe check
        dedupe_hash = KycSession.compute_dedupe_hash(license_number)

        existing = (
            UserVerification.objects
            .filter(dedupe_hash=dedupe_hash, verified=True)
            .exclude(user=request.user)
            .first()
        )
        if existing:
            return Response({"detail": "This license is already used for verification"}, status=status.HTTP_409_CONFLICT)

        # Call Surepass
        client = SurepassClient()
        try:
            dob_str = dob.strftime("%Y-%m-%d")
            resp = client.driving_license_verify(license_number=license_number, dob=dob_str)
        except SurepassError as e:
            vendor_status = getattr(e, "status_code", None) or getattr(e, "http_status", None)
            msg = str(e)

            if vendor_status == 429 or "Rate Limited" in msg:
                return Response(
                    {
                        "detail": "Rate limited by DL provider. Please wait and try again.",
                        "code": "RATE_LIMITED",
                    },
                    status=status.HTTP_429_TOO_MANY_REQUESTS,
                )

            if vendor_status in (400, 401, 403):
                return Response({"detail": msg}, status=vendor_status)

            return Response({"detail": msg}, status=status.HTTP_502_BAD_GATEWAY)

        # Success => create session + update profile
        data = resp.get("data", {}) or {}

        dl_name = data.get("name") or ""
        dl_gender = (data.get("gender") or "").strip()
        dl_dob_str = data.get("dob")

        dl_dob = None
        if dl_dob_str:
            try:
                dl_dob = timezone.datetime.fromisoformat(dl_dob_str).date()
            except ValueError:
                dl_dob = None

        # Debug: Print fetched DL details
        # print(f"[DL DEBUG] Fetched DL Details:")
        # print(f"  Name: '{dl_name}'")
        # print(f"  DOB: '{dl_dob_str}' -> {dl_dob}")
        # print(f"  Gender: '{dl_gender}'")
        # print(f"  License Number: {data.get('license_number')}")

        img_b64 = data.get("profile_image") if data.get("has_image") else None

        session = KycSession.objects.create(
            user=request.user,
            method="DL",
            status="DL_VERIFIED",
            dedupe_hash=dedupe_hash,
            surepass_client_id=data.get("client_id"),
            ekyc_full_name=dl_name,
            ekyc_gender=dl_gender,
            ekyc_dob=dl_dob,
            vendor_reference_id=data.get("license_number"),
            vendor_uniqueness_id=data.get("client_id"),
            id_card_image_b64=img_b64,
            expires_at=KycSession.default_expiry(),
        )

        profile.profile_status = "KYC_IN_PROGRESS"
        profile.verification_method = "DL"
        profile.kyc_status = "OTP_VERIFIED"  # Reuse this status for DL (means details fetched)
        profile.kyc_fail_reason = None
        profile.save(update_fields=[
            "profile_status", "verification_method", "kyc_status", "kyc_fail_reason", "updated_at"
        ])

        return Response({
            "kyc_session_uid": str(session.uid),
            "expires_at": session.expires_at,
            "status": "DL_VERIFIED",
            "next": "VERIFY_DETAILS",
        }, status=status.HTTP_200_OK)


class DLKycVerifyDetailsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.user_type != "OPERATOR":
            return Response({"detail": "Only operator"}, status=status.HTTP_403_FORBIDDEN)

        ser = DLVerifyDetailsSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        session_uid = ser.validated_data["kyc_session_uid"]
        user_full_name = (ser.validated_data.get("full_name") or "").strip()
        user_gender = (ser.validated_data.get("gender") or "").strip()
        user_state = (ser.validated_data.get("state") or "").strip()
        user_district = (ser.validated_data.get("district") or "").strip()
        user_address = (ser.validated_data.get("address") or "").strip()

        session = KycSession.objects.filter(uid=session_uid, user=request.user, method="DL").first()
        if not session:
            return Response({"detail": "Invalid KYC session"}, status=status.HTTP_404_NOT_FOUND)

        if session.is_expired():
            session.status = "EXPIRED"
            session.save(update_fields=["status", "updated_at"])
            return Response({"detail": "Session expired"}, status=status.HTTP_400_BAD_REQUEST)

        # Allow from DL_VERIFIED status
        if session.status != "DL_VERIFIED":
            return Response({"detail": f"Invalid state: {session.status}"}, status=status.HTTP_400_BAD_REQUEST)

        # Get stored DL details
        ekyc_name = (session.ekyc_full_name or "").strip()
        ekyc_dob = session.ekyc_dob
        ekyc_gender = (session.ekyc_gender or "").strip()

        # Use DOB from session (already collected at DL input screen)
        user_dob = ekyc_dob

        # Debug: Print comparison details
        # print(f"[DL VERIFY DEBUG] User Input:")
        # print(f"  Name: '{user_full_name}'")
        # print(f"  DOB: {user_dob} (from session)")
        # print(f"  Gender: '{user_gender}' (will be saved without verification)")
        # print(f"[DL VERIFY DEBUG] Stored DL Details:")
        # print(f"  Name: '{ekyc_name}'")
        # print(f"  DOB: {ekyc_dob}")
        # print(f"  Gender: '{ekyc_gender}' (not verified - DL gender may be inaccurate)")

        
        user_name_normalized = " ".join(user_full_name.split()) if user_full_name else ""
        ekyc_name_normalized = " ".join(ekyc_name.split()) if ekyc_name else ""
        name_ok = bool(user_name_normalized.upper() == ekyc_name_normalized.upper())
        score = 1.0 if name_ok else 0.0  # Store 1.0 for exact match, 0.0 for mismatch
        
        dob_ok = True  # DOB already verified at DL input, so always match
        gender_ok = True  # Gender not verified - always accept user input

        # print(f"[DL VERIFY DEBUG] Comparison Results:")
        # print(f"  Name Match: Exact match required, OK: {name_ok}")
        # print(f"  User Name (normalized): '{user_name_normalized.upper()}'")
        # print(f"  DL Name (normalized): '{ekyc_name_normalized.upper()}'")
        # print(f"  DOB Match: {dob_ok}")
        # print(f"  Gender Match: {gender_ok} (skipped - using user input)")
        # print(f"  Overall Match: {name_ok and dob_ok}")

        # Store match results
        session.name_match_score = score
        session.name_match = name_ok
        session.dob_match = dob_ok
        session.gender_match = None  # Gender not verified for DL

        profile: OperatorProfile = request.user.operator_profile

        # Only verify name and DOB for DL (gender is saved from user input without verification)
        if name_ok and dob_ok:
            # All match - update user profile and proceed
            if user_full_name:
                name_parts = user_full_name.split(maxsplit=2)
                request.user.first_name = name_parts[0] if len(name_parts) > 0 else ""
                request.user.last_name = name_parts[-1] if len(name_parts) > 1 else ""
                request.user.middle_name = name_parts[1] if len(name_parts) > 2 else ""
                request.user.full_name = user_full_name
                request.user.save(update_fields=["first_name", "middle_name", "last_name", "full_name", "updated_at"])

            # Update profile
            profile.date_of_birth = user_dob
            profile.gender = user_gender
            profile.current_state = user_state if user_state else None
            profile.current_district = user_district if user_district else None
            profile.current_address = user_address if user_address else None
            profile.profile_status = "KYC_IN_PROGRESS"
            profile.kyc_status = "FACE_PENDING"
            profile.kyc_fail_reason = None
            profile.save(update_fields=[
                "date_of_birth", "gender", "current_state", "current_district", "current_address",
                "profile_status", "kyc_status", "kyc_fail_reason", "updated_at"
            ])

            # Update session
            session.status = "DETAILS_VERIFIED"
            session.save(update_fields=[
                "name_match_score", "name_match", "dob_match", "gender_match",
                "status", "updated_at"
            ])

            return Response({
                "status": "DETAILS_VERIFIED",
                "next": "FACE_LIVENESS",
                "match": True
            })
        else:
            # Mismatch - allow retry
            session.save(update_fields=[
                "name_match_score", "name_match", "dob_match", "gender_match",
                "updated_at"
            ])

            profile.kyc_status = "DL_VERIFIED"
            profile.kyc_fail_reason = "Details mismatch"
            profile.save(update_fields=["kyc_status", "kyc_fail_reason", "updated_at"])

            return Response({
                "status": "DL_VERIFIED",
                "match": False,
                "mismatches": {
                    "name": not name_ok,
                    "date_of_birth": not dob_ok,
                    # Gender not included in mismatches - not verified
                },
                "name_match_score": score,
                "message": "Details do not match Driving License. Please verify and try again."
            }, status=status.HTTP_400_BAD_REQUEST)


class FaceLivenessView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.user_type != "OPERATOR":
            return Response({"detail": "Only operator"}, status=status.HTTP_403_FORBIDDEN)

        ser = KycSessionUidSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        session_uid = ser.validated_data["kyc_session_uid"]

        session = KycSession.objects.filter(uid=session_uid, user=request.user).first()
        if not session:
            return Response({"detail": "Invalid KYC session"}, status=status.HTTP_404_NOT_FOUND)

        if session.is_expired():
            session.status = "EXPIRED"
            session.save(update_fields=["status", "updated_at"])
            return Response({"detail": "Session expired"}, status=status.HTTP_400_BAD_REQUEST)

        # Allow from DETAILS_VERIFIED, OTP_VERIFIED (Aadhaar), or DL_VERIFIED (DL)
        # Allow retry from FAILED state if attempts not exceeded
        if session.status == "FAILED" and session.liveness_attempts < 3:
            # Restore to appropriate status based on method
            restore_status = "DL_VERIFIED" if session.method == "DL" else "DETAILS_VERIFIED"
            session.status = restore_status
            session.save(update_fields=["status", "updated_at"])
        elif session.status not in ["DETAILS_VERIFIED", "OTP_VERIFIED", "DL_VERIFIED"]:
            return Response({"detail": "Details not verified"}, status=status.HTTP_400_BAD_REQUEST)

        if session.liveness_attempts >= 3:
            return Response({"detail": "Liveness attempts exceeded"}, status=status.HTTP_429_TOO_MANY_REQUESTS)

        selfie = request.FILES.get("selfie")
        if not selfie:
            return Response({"detail": "selfie file required"}, status=status.HTTP_400_BAD_REQUEST)

        session.liveness_attempts += 1
        session.save(update_fields=["liveness_attempts", "updated_at"])

        client = SurepassClient()
        try:
            resp = client.face_liveness(selfie_bytes=selfie.read(), filename=selfie.name)
        except SurepassError as e:
            return Response({"detail": str(e)}, status=status.HTTP_502_BAD_GATEWAY)

        d = resp.get("data", {}) or {}
        live = bool(d.get("live", False))
        confidence = float(d.get("confidence", 0))

        
        ver, _ = UserVerification.objects.get_or_create(
            user=request.user,
            method=session.method,  
            defaults={"dedupe_hash": session.dedupe_hash},
        )
        ver.dedupe_hash = session.dedupe_hash
        ver.liveness_pass = live
        ver.liveness_confidence = confidence
        ver.save()

        profile = request.user.operator_profile
        profile.kyc_status = "FACE_PENDING" if live else "DETAILS_VERIFIED"
        profile.save(update_fields=["kyc_status", "updated_at"])

        return Response({"live": live, "confidence": confidence, "next": "FACE_MATCH" if live else "RETRY"})


class FaceMatchView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.user_type != "OPERATOR":
            return Response({"detail": "Only operator"}, status=status.HTTP_403_FORBIDDEN)

        ser = KycSessionUidSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        session_uid = ser.validated_data["kyc_session_uid"]

        session = KycSession.objects.filter(uid=session_uid, user=request.user).first()
        if not session:
            return Response({"detail": "Invalid KYC session"}, status=status.HTTP_404_NOT_FOUND)

        if session.is_expired():
            session.status = "EXPIRED"
            session.save(update_fields=["status", "updated_at"])
            return Response({"detail": "Session expired"}, status=status.HTTP_400_BAD_REQUEST)

       
        if session.status == "FAILED" and session.face_attempts < 3:
            session.status = "DETAILS_VERIFIED"
            session.save(update_fields=["status", "updated_at"])
        elif session.status != "DETAILS_VERIFIED":
            return Response({"detail": "Details not verified"}, status=status.HTTP_400_BAD_REQUEST)

        if session.face_attempts >= 3:
            return Response({"detail": "Face match attempts exceeded"}, status=status.HTTP_429_TOO_MANY_REQUESTS)

        selfie = request.FILES.get("selfie")
        if not selfie:
            return Response({"detail": "selfie file required"}, status=status.HTTP_400_BAD_REQUEST)

        if not session.id_card_image_b64:
            return Response({"detail": "ID image not available. Restart KYC."}, status=status.HTTP_400_BAD_REQUEST)

        session.face_attempts += 1
        session.save(update_fields=["face_attempts", "updated_at"])

        try:
            id_bytes = base64.b64decode(session.id_card_image_b64)
        except Exception:
            return Response({"detail": "Invalid ID image. Restart KYC."}, status=status.HTTP_400_BAD_REQUEST)

        client = SurepassClient()
        try:
            resp = client.face_match(selfie_bytes=selfie.read(), id_card_bytes=id_bytes, selfie_filename=selfie.name, id_filename="aadhaar.jpg")
        except SurepassError as e:
            return Response({"detail": str(e)}, status=status.HTTP_502_BAD_GATEWAY)

        d = resp.get("data", {}) or {}
        match_status = bool(d.get("match_status", False))
        confidence = float(d.get("confidence", 0))

        face_pass = match_status and confidence >= settings.KYC_FACE_MATCH_THRESHOLD

        
        ver, _ = UserVerification.objects.get_or_create(
            user=request.user,
            method=session.method,  
            defaults={"dedupe_hash": session.dedupe_hash},
        )
        ver.dedupe_hash = session.dedupe_hash
        ver.name_match = session.name_match
        ver.name_match_score = session.name_match_score
        ver.dob_match = session.dob_match

        ver.face_match_pass = face_pass
        ver.face_match_confidence = confidence

        ver.vendor_reference_id = session.vendor_reference_id
        ver.vendor_uniqueness_id = session.vendor_uniqueness_id

        if face_pass:
            ver.verified = True
            ver.verified_at = timezone.now()
        else:
            ver.verified = False
            ver.verified_at = None

        ver.save()

        profile = request.user.operator_profile
        if face_pass:
            
            selfie.seek(0) 
            request.user.photo = selfie
            request.user.save(update_fields=["photo", "updated_at"])
            
            profile.profile_status = "VERIFIED"
            profile.kyc_status = "VERIFIED"
            profile.kyc_verified_at = timezone.now()
            profile.kyc_fail_reason = None
            profile.save(update_fields=["profile_status", "kyc_status", "kyc_verified_at", "kyc_fail_reason", "updated_at"])

            
            session.status = "COMPLETED"
            session.save(update_fields=["status", "updated_at"])
            session.clear_sensitive()

            return Response({"verified": True, "confidence": confidence})
        else:
            
            if session.face_attempts >= 3:
                profile.kyc_status = "FAILED"
                profile.kyc_fail_reason = "Face match failed"
                profile.save(update_fields=["kyc_status", "kyc_fail_reason", "updated_at"])

                session.status = "FAILED"
                session.save(update_fields=["status", "updated_at"])
                return Response({"verified": False, "confidence": confidence, "detail": "Face match failed. Maximum attempts reached."}, status=status.HTTP_400_BAD_REQUEST)
            else:
                
                profile.kyc_status = "FACE_PENDING"
                profile.kyc_fail_reason = "Face match failed"
                profile.save(update_fields=["kyc_status", "kyc_fail_reason", "updated_at"])

                session.save(update_fields=["updated_at"])
                return Response({"verified": False, "confidence": confidence, "next": "RETRY", "message": "Face match failed. Please try again."}, status=status.HTTP_400_BAD_REQUEST)
