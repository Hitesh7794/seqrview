import 'package:flutter/material.dart';
import 'dart:ui'; // For verifying blur if needed, though standard shadow is enough

class SupportFloatingButton extends StatelessWidget {
  const SupportFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // "Mix colors" - Gradient
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.8), 
            const Color(0xFFB6BFDC).withValues(alpha: 0.8) // Mixed with Indigo
          ], 
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        // "Little transparent" - handled by withOpacity above, but could also be overall opacity.
        // Let's keep the shape circle
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA1A2DF).withValues(alpha: 0.3), // Colored shadow for glow
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Support feature coming soon!")),
          );
        },
        // Make the button itself transparent to show the container's decoration
        backgroundColor: Colors.transparent,
        elevation: 0, 
        highlightElevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.headset_mic, color: Colors.white),
      ),
    );
  }
}
