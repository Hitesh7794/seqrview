import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app/session_controller.dart';
import '../../app/onboarding_stage.dart';

class KycMethodSelectScreen extends StatefulWidget {
  final SessionController session;
  const KycMethodSelectScreen({super.key, required this.session});

  @override
  State<KycMethodSelectScreen> createState() => _KycMethodSelectScreenState();
}

class _KycMethodSelectScreenState extends State<KycMethodSelectScreen> {
  // Theme State
  bool get _isDark => widget.session.isDark;

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_update);
  }

  @override
  void dispose() {
    widget.session.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Colors
    final bg = _isDark ? const Color(0xFF0C0E11) : const Color(0xFFF5F7FA);
    final textMain = _isDark ? Colors.white : const Color(0xFF1F2937);
    final textSub = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final cardColor = _isDark ? const Color(0xFF161A22) : Colors.white;
    final borderColor = _isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    // Specific Card Colors
    final aadhaarIconBg = const Color(0xFFE3F2FD); // Light Blue
    final aadhaarIconColor = const Color(0xFF2196F3); // Blue
    
    final dlIconBg = const Color(0xFFF3E5F5); // Light Purple
    final dlIconColor = const Color(0xFF9C27B0); // Purple

    final infoCardBg = _isDark ? const Color(0xFF1E2030) : const Color(0xFFEBEBFF);
    final infoTextColor = _isDark ? const Color(0xFFB0B0E0) : const Color(0xFF4A4A8A);

    // Make Status Bar Transparent & Full Screen
    SystemChrome.setSystemUIOverlayStyle(
      (_isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDark ? Brightness.light : Brightness.dark, 
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Logos & Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Logos
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/logo.png', height: 32),
                      
                    
                    ],
                  ),

                  // Right: Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => widget.session.toggleTheme(),
                        icon: Icon(
                          _isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                          color: textMain,
                        ),
                        tooltip: "Toggle Theme",
                      ),
                      IconButton(
                        onPressed: () {
                          // print("Logout pressed"); // Debugging
                          widget.session.logout();
                        },
                        icon: Icon(Icons.logout_rounded, color: textMain),
                        tooltip: "Logout",
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      "Choose Verification\nMethod",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Subtitle
                    Text(
                      "Select how you want to verify your identity.",
                      style: TextStyle(
                        fontSize: 16,
                        color: textSub,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // -- Card 1: Aadhaar --
                    _buildMethodCard(
                      title: "Verify via Aadhaar",
                      subtitle: "Fastest & Paperless",
                      icon: Icons.fingerprint,
                      iconBg: aadhaarIconBg,
                      iconColor: aadhaarIconColor,
                      cardColor: cardColor,
                      textColor: textMain,
                      subTextColor: textSub,
                      borderColor: borderColor,
                      onTap: () async {
                        await widget.session.clearKycSession();
                        widget.session.setStage(OnboardingStage.aadhaarNumber);
                      },
                    ),
                    const SizedBox(height: 16),

                    // -- Card 2: Driving Licence --
                    _buildMethodCard(
                      title: "Verify via Driving Licence",
                      subtitle: "Secure manual upload",
                      icon: Icons.badge_outlined,
                      iconBg: dlIconBg,
                      iconColor: dlIconColor,
                      cardColor: cardColor,
                      textColor: textMain,
                      subTextColor: textSub,
                      borderColor: borderColor,
                      onTap: () async {
                        await widget.session.clearKycSession();
                        widget.session.setStage(OnboardingStage.dlNumber);
                      },
                    ),

                    const Spacer(), // Pushes content to bottom

                    // -- Info Card --
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: infoCardBg,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: infoTextColor, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                "Why verify?",
                                style: TextStyle(
                                  color: textMain,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Verification helps us secure your account and comply with local regulations for telecommunications.",
                            style: TextStyle(
                              color: infoTextColor,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    // Center(
                    //   child: Text(
                    //     "POWERED BY SECUREGOV CONNECT",
                    //     style: TextStyle(
                    //       color: textSub.withOpacity(0.5),
                    //       fontSize: 10,
                    //       fontWeight: FontWeight.bold,
                    //       letterSpacing: 1.5,
                    //     ),
                    //   ),
                    // ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
             // Theme Toggle - Moved inside Column? No, needs to be floating? 
             // Logic change: If we use Column + Spacer, the Theme Toggle has to be stack-positioned or integrated. 
             // Let's put Theme Toggle in the top right with logout? Or floating bottom right.
             // If floating, we need a Stack wrapper again, or Overlay. 
             // Let's integrate Theme Toggle near Logout or keep Stack.
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: _isDark ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: subTextColor.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}
