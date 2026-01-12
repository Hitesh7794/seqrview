import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'session_controller.dart';
import 'onboarding_stage.dart';

const splashPath = '/splash';
const mobilePath = '/auth/mobile';
const otpPath = '/auth/otp';

const profilePath = '/onboarding/profile';
const kycMethodPath = '/onboarding/kyc-method';

const aadhaarNumberPath = '/onboarding/aadhaar-number';
const aadhaarOtpPath = '/onboarding/aadhaar-otp';
const livenessPath = '/onboarding/liveness';
const faceMatchPath = '/onboarding/face-match';

const failedPath = '/kyc/failed';
const rejectedPath = '/kyc/rejected';

const homePath = '/home';

String _target(OnboardingStage s) {
  switch (s) {
    case OnboardingStage.loading:
      return splashPath;
    case OnboardingStage.unauthenticated:
      return mobilePath;

    case OnboardingStage.draftProfile:
      return profilePath;
    case OnboardingStage.chooseKycMethod:
      return kycMethodPath;
    case OnboardingStage.aadhaarNumber:
      return aadhaarNumberPath;
    case OnboardingStage.aadhaarOtp:
      return aadhaarOtpPath;
    case OnboardingStage.liveness:
      return livenessPath;
    case OnboardingStage.faceMatch:
      return faceMatchPath;

    case OnboardingStage.failed:
      return failedPath;
    case OnboardingStage.rejected:
      return rejectedPath;
    case OnboardingStage.verified:
      return homePath;
  }
}

GoRouter buildRouter({
  required SessionController session,
  required Widget Function() splash,
  required Widget Function() mobile,
  required Widget Function() otp,
  required Widget Function() profile,
  required Widget Function() kycMethod,
  required Widget Function() aadhaarNumber,
  required Widget Function() aadhaarOtp,
  required Widget Function() liveness,
  required Widget Function() faceMatch,
  required Widget Function() failed,
  required Widget Function() rejected,
  required Widget Function() home,
}) {
  return GoRouter(
    initialLocation: splashPath,
    refreshListenable: session,
    redirect: (context, state) {
      // While loading => stay on splash
      if (session.stage == OnboardingStage.loading) {
        return state.matchedLocation == splashPath ? null : splashPath;
      }

      // Allow OTP screen if user just requested OTP (unauthenticated stage)
      if (state.matchedLocation == otpPath && session.stage == OnboardingStage.unauthenticated) {
        return null;
      }

      final target = _target(session.stage);
      if (state.matchedLocation == target) return null;
      return target;
    },
    routes: [
      GoRoute(path: splashPath, builder: (_, __) => splash()),
      GoRoute(path: mobilePath, builder: (_, __) => mobile()),
      GoRoute(path: otpPath, builder: (_, __) => otp()),

      GoRoute(path: profilePath, builder: (_, __) => profile()),
      GoRoute(path: kycMethodPath, builder: (_, __) => kycMethod()),
      GoRoute(path: aadhaarNumberPath, builder: (_, __) => aadhaarNumber()),
      GoRoute(path: aadhaarOtpPath, builder: (_, __) => aadhaarOtp()),
      GoRoute(path: livenessPath, builder: (_, __) => liveness()),
      GoRoute(path: faceMatchPath, builder: (_, __) => faceMatch()),

      GoRoute(path: failedPath, builder: (_, __) => failed()),
      GoRoute(path: rejectedPath, builder: (_, __) => rejected()),
      GoRoute(path: homePath, builder: (_, __) => home()),
    ],
  );
}
