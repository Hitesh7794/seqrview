
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/session_controller.dart';

class BlockedUserScreen extends StatelessWidget {
  final SessionController session;

  const BlockedUserScreen({super.key, required this.session});

  Future<void> _launchSupport() async {
    final Uri url = Uri.parse('https://wa.me/917737886504');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = session.isDark;
    final bg = isDark ? const Color(0xFF0D1117) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSub = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                "Access Denied",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                "Your account has been blocked or suspended by the administrator.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: textSub,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "If you believe this is a mistake, please contact support.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: textSub,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 32),

              // Support Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _launchSupport,
                  icon: const Icon(Icons.support_agent),
                  label: const Text("Contact Support via WhatsApp"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // WhatsApp color
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Logout Button
              TextButton.icon(
                onPressed: () => session.logout(),
                icon: const Icon(Icons.logout, size: 20),
                label: const Text("Logout"),
                style: TextButton.styleFrom(
                  foregroundColor: textSub,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
