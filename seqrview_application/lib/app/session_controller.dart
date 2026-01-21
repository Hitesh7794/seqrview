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
  
  // ✅ NEW (in-memory only): Aadhaar details from OTP submission (NOT persisted)
  Map<String, dynamic>? aadhaarDetails;

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
    await api.logout(); // Call server to invalidate refresh token
    await storage.clearAll();
    otpSessionUid = null;
    mobile = null;
    kycSessionUid = null;
    lastAadhaarNumber = null;
    aadhaarDetails = null;
    stage = OnboardingStage.unauthenticated;
    notifyListeners();
  }

  Future<void> resetKyc() async {
    try {
      await api.dio.post('/api/kyc/aadhaar/reset/');
    } catch (_) {
      // ignore reset errors; we'll still clear locally
    }
    await clearKycSession();
    stage = OnboardingStage.aadhaarNumber;
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
    } catch (e) {
      // If 401 after refresh attempt, or any other error => logout for safety
      // This prevents infinite retry loops when user doesn't exist in DB
      await logout();
    }
  }

  OnboardingStage _computeStage(String profileStatus, String kycStatus, String method) {
    if (profileStatus == 'VERIFIED') return OnboardingStage.verified;
    if (profileStatus == 'REJECTED') return OnboardingStage.rejected;

    // ✅ Check for FAILED status first (regardless of profile status)
    if (kycStatus == 'FAILED') return OnboardingStage.failed;

    // ✅ NEW FLOW: Skip profile screen, go directly to KYC method selection
    if (profileStatus == 'DRAFT') {
      // New operator - go to method selection screen
      return OnboardingStage.chooseKycMethod;
    }
    
    if (profileStatus == 'PROFILE_FILLED') return OnboardingStage.chooseKycMethod;

    if (profileStatus == 'KYC_IN_PROGRESS') {
      if (method == 'AADHAAR') {
        // If OTP_SENT, go to Number screen (which handles overlay or re-entry)
        // This avoids showing the broken standalone AadhaarOtpScreen on restart
        if (kycStatus == 'OTP_SENT') return OnboardingStage.aadhaarNumber;
        // OTP_VERIFIED means details need to be verified (new flow)
        if (kycStatus == 'OTP_VERIFIED') {
          // If we have active KYC session, proceed to verify details screen
          if (kycSessionUid != null && kycSessionUid!.isNotEmpty) {
            return OnboardingStage.verifyDetails;
          }
          // Resuming app - no active session, restart
          return OnboardingStage.aadhaarNumber;
        }
        // After details verified, proceed to face match (which combines liveness + match)
        if (kycStatus == 'DETAILS_VERIFIED' || kycStatus == 'FACE_PENDING') return OnboardingStage.faceMatch;
      } else if (method == 'DL') {
        // DL flow: DL_VERIFIED means details need to be verified
        if (kycStatus == 'DL_VERIFIED') {
          // If we have active KYC session, proceed to verify details screen
          if (kycSessionUid != null && kycSessionUid!.isNotEmpty) {
            return OnboardingStage.verifyDetails;
          }
          // Resuming app - no active session, restart
          return OnboardingStage.dlNumber;
        }
        // After details verified, proceed to face match (which combines liveness + match)
        if (kycStatus == 'DETAILS_VERIFIED' || kycStatus == 'FACE_PENDING') return OnboardingStage.faceMatch;
      }
      return OnboardingStage.chooseKycMethod;
    }

    // Default: new operator goes to Aadhaar KYC
    return OnboardingStage.aadhaarNumber;
  }

  OnboardingStage _guardStage(OnboardingStage s) {
    // If app resumes mid-KYC but we don't have kycSessionUid stored,
    // route user back to method selection to restart cleanly.
    final needsKycUid = (s == OnboardingStage.aadhaarOtp ||
        s == OnboardingStage.verifyDetails ||
        s == OnboardingStage.liveness ||
        s == OnboardingStage.faceMatch);

    if (needsKycUid && (kycSessionUid == null || kycSessionUid!.isEmpty)) {
      return OnboardingStage.chooseKycMethod;
    }
    return s;
  }
}
