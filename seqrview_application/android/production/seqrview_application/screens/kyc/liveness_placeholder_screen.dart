import 'package:flutter/material.dart';
import '../../app/session_controller.dart';

class LivenessPlaceholderScreen extends StatelessWidget {
  final SessionController session;
  const LivenessPlaceholderScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Face Liveness")),
      body: const Center(
        child: Text("Liveness screen placeholder.\nNext we will integrate camera + API."),
      ),
    );
  }
}
