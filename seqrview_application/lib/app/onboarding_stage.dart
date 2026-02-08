enum OnboardingStage {
  unauthenticated,
  loading,

  draftProfile,
  chooseKycMethod,
  aadhaarNumber,
  aadhaarOtp,
  dlNumber,
  verifyDetails,
  liveness,
  faceMatch,

  verified,
  failed,
  rejected,
  blocked,
}
