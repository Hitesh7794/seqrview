class OperatorProfile {
  final String profileStatus;
  final String kycStatus;
  final String verificationMethod;
  final String? kycFailReason;

  OperatorProfile({
    required this.profileStatus,
    required this.kycStatus,
    required this.verificationMethod,
    this.kycFailReason,
  });

  factory OperatorProfile.fromJson(Map<String, dynamic> j) {
    return OperatorProfile(
      profileStatus: (j['profile_status'] ?? 'DRAFT').toString(),
      kycStatus: (j['kyc_status'] ?? 'NOT_STARTED').toString(),
      verificationMethod: (j['verification_method'] ?? 'NONE').toString(),
      kycFailReason: j['kyc_fail_reason']?.toString(),
    );
  }
}
