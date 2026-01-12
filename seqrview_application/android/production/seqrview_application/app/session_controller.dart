import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/token_storage.dart';
import 'onboarding_stage.dart';

class SessionController extends ChangeNotifier {
  final ApiClient api;
  final TokenStorage storage;

  OnboardingStage stage = OnboardingStage.loading;

  String? otpSessionUid; // in-memory
  String? mobile; // loaded from storage
  String? kycSessionUid; // loaded from storage

  // ✅ NEW (in-memory only): last Aadhaar entered (NOT persisted)
  String? lastAadhaarNumber;

  SessionController({required this.api, required this.storage});

  void setStage(OnboardingStage s) {
    stage = s;
    notifyListeners();
  }

  void setLastAadhaarNumber(String idNumber) {
    lastAadhaarNumber = idNumber;
  }

  Future<void> setKycSessionUid(String uid) async {
    kycSessionUid = uid;
    await storage.saveKycSessionUid(uid);
  }

  Future<void> clearKycSession() async {
    kycSessionUid = null;
    await storage.clearKycSessionUid();
  }

  Future<void> logout() async {
    await storage.clearAll();
    otpSessionUid = null;
    mobile = null;
    kycSessionUid = null;
    lastAadhaarNumber = null;
    stage = OnboardingStage.unauthenticated;
    notifyListeners();
  }

  Future<void> bootstrap() async {
    stage = OnboardingStage.loading;
    notifyListeners();

    // load convenience values
    mobile = await storage.getMobile();
    kycSessionUid = await storage.getKycSessionUid();

    final access = await storage.getAccess();
    if (access == null || access.isEmpty) {
      stage = OnboardingStage.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final res = await api.dio.get('/api/operators/profile/');
      final data = res.data as Map<String, dynamic>;

      final profileStatus = (data['profile_status'] ?? 'DRAFT').toString();
      final kycStatus = (data['kyc_status'] ?? 'NOT_STARTED').toString();
      final verificationMethod = (data['verification_method'] ?? 'NONE').toString();

      // ✅ OPTIONAL improvement: if backend ever returns active kyc session uid, store it
      // (If not present, this does nothing.)
      final serverKycUid = (data['kyc_session_uid'] ??
          data['active_kyc_session_uid'] ??
          data['current_kyc_session_uid'])
          ?.toString();

      if (serverKycUid != null && serverKycUid.isNotEmpty) {
        await setKycSessionUid(serverKycUid);
      }

      stage = _computeStage(profileStatus, kycStatus, verificationMethod);
      stage = _guardStage(stage); // avoid stuck if kycSessionUid missing
      notifyListeners();
    } catch (_) {
      // token invalid or API down => logout for safety
      await logout();
    }
  }

  OnboardingStage _computeStage(String profileStatus, String kycStatus, String method) {
    if (profileStatus == 'VERIFIED') return OnboardingStage.verified;
    if (profileStatus == 'REJECTED') return OnboardingStage.rejected;

    if (profileStatus == 'DRAFT') return OnboardingStage.draftProfile;
    if (profileStatus == 'PROFILE_FILLED') return OnboardingStage.chooseKycMethod;

    if (profileStatus == 'KYC_IN_PROGRESS') {
      if (method == 'AADHAAR') {
        if (kycStatus == 'OTP_SENT') return OnboardingStage.aadhaarOtp;
        if (kycStatus == 'OTP_VERIFIED') return OnboardingStage.liveness;
        if (kycStatus == 'FACE_PENDING') return OnboardingStage.faceMatch;
        if (kycStatus == 'FAILED') return OnboardingStage.failed;
      }
      return OnboardingStage.chooseKycMethod;
    }

    return OnboardingStage.draftProfile;
  }

  OnboardingStage _guardStage(OnboardingStage s) {
    // If app resumes mid-KYC but we don't have kycSessionUid stored,
    // route user back to Aadhaar number to restart cleanly.
    final needsKycUid = (s == OnboardingStage.aadhaarOtp ||
        s == OnboardingStage.liveness ||
        s == OnboardingStage.faceMatch);

    if (needsKycUid && (kycSessionUid == null || kycSessionUid!.isEmpty)) {
      return OnboardingStage.aadhaarNumber;
    }
    return s;
  }
}
