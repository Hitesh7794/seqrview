import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'app/session_controller.dart';
import 'app/router.dart';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';

import 'screens/auth/mobile_number_screen.dart';
import 'screens/auth/otp_verify_screen.dart';

import 'screens/onboarding/profile_form_screen.dart';
import 'screens/onboarding/kyc_method_select_screen.dart';

import 'screens/kyc/aadhaar_number_screen.dart';
import 'screens/kyc/aadhaar_otp_screen.dart';
import 'screens/kyc/dl_number_screen.dart';
import 'screens/kyc/aadhaar_verify_details_screen.dart';
import 'screens/kyc/liveness_placeholder_screen.dart';
import 'screens/kyc/face_match_placeholder_screen.dart';
import 'screens/kyc/failed_screen.dart';
import 'screens/kyc/rejected_screen.dart';
import 'screens/main_screen.dart';

void main() {
  final storage = TokenStorage();
  final api = ApiClient(storage);
  final session = SessionController(api: api, storage: storage);

  runApp(MyApp(session: session));
}

class MyApp extends StatefulWidget {
  final SessionController session;
  const MyApp({super.key, required this.session});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final router = buildRouter(
    session: widget.session,
    splash: () => SplashScreen(session: widget.session),
    mobile: () => MobileNumberScreen(session: widget.session),
    otp: () => OtpVerifyScreen(session: widget.session),

    profile: () => ProfileFormScreen(session: widget.session),
    kycMethod: () => KycMethodSelectScreen(session: widget.session),

    aadhaarNumber: () => AadhaarNumberScreen(session: widget.session),
    aadhaarOtp: () => AadhaarOtpScreen(session: widget.session),
    dlNumber: () => DLNumberScreen(session: widget.session),
    verifyDetails: () => AadhaarVerifyDetailsScreen(session: widget.session),

    liveness: () => LivenessPlaceholderScreen(session: widget.session),
    faceMatch: () => FaceMatchPlaceholderScreen(session: widget.session),

    failed: () => FailedScreen(session: widget.session),
    rejected: () => RejectedScreen(session: widget.session),
    home: () => MainScreen(session: widget.session),
  );

  @override
  void initState() {
    super.initState();
    widget.session.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
