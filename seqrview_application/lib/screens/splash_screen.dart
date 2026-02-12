import 'package:flutter/material.dart';
import '../app/session_controller.dart';

class SplashScreen extends StatelessWidget {
  final SessionController session;
  const SplashScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 250),
              width: MediaQuery.of(context).size.width * 0.7,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 60), // More breathing room
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            const Text("Loading..."),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => session.bootstrap(),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}
