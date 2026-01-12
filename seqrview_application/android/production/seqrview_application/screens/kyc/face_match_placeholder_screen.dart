import 'package:flutter/material.dart';
import '../../app/session_controller.dart';

class FaceMatchPlaceholderScreen extends StatelessWidget {
  final SessionController session;
  const FaceMatchPlaceholderScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Face Match")),
      body: const Center(
        child: Text("Face match screen placeholder.\nNext we will integrate camera + API."),
      ),
    );
  }
}
