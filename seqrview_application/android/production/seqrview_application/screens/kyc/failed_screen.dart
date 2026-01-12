import 'package:flutter/material.dart';
import '../../app/session_controller.dart';
import '../../app/onboarding_stage.dart';

class FailedScreen extends StatelessWidget {
  final SessionController session;
  const FailedScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("KYC Failed")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Your KYC failed. You can restart Aadhaar verification.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  await session.storage.clearKycSessionUid();
                  session.kycSessionUid = null;
                  session.setStage(OnboardingStage.aadhaarNumber);
                },
                child: const Text("Restart KYC"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
