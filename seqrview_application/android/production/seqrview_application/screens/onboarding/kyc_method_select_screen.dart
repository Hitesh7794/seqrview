import 'package:flutter/material.dart';
import '../../app/session_controller.dart';
import '../../app/onboarding_stage.dart';

class KycMethodSelectScreen extends StatelessWidget {
  final SessionController session;
  const KycMethodSelectScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choose Verification Method")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Select how you want to verify your identity.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  session.setStage(OnboardingStage.aadhaarNumber);
                },
                child: const Text("Verify via Aadhaar"),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Driving Licence flow will be added next.")),
                  );
                },
                child: const Text("Verify via Driving Licence (Coming soon)"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
