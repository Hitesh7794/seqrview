import 'package:flutter/material.dart';
import '../../app/session_controller.dart';

class RejectedScreen extends StatelessWidget {
  final SessionController session;
  const RejectedScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile Rejected")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Your profile was rejected. Please contact support.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => session.logout(),
                child: const Text("Logout"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
