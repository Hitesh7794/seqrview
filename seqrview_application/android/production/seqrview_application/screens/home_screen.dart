import 'package:flutter/material.dart';
import '../app/session_controller.dart';

class HomeScreen extends StatelessWidget {
  final SessionController session;
  const HomeScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          IconButton(onPressed: () => session.logout(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: const Center(child: Text("Verified Operator Home (placeholder)")),
    );
  }
}
