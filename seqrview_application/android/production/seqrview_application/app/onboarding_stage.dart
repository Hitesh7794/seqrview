enum OnboardingStage {
  unauthenticated,
  loading,

  draftProfile,
  chooseKycMethod,
  aadhaarNumber,
  aadhaarOtp,
  liveness,
  faceMatch,

  verified,
  failed,
  rejected,
}
