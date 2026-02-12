import 'dart:async';
import 'dart:ui'; // For ImageFilter
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/session_controller.dart';
import '../../app/onboarding_stage.dart';
import 'aadhaar_otp_screen.dart'; // Import Sheet Widget
import '../../widgets/global_support_button.dart';

class AadhaarNumberScreen extends StatefulWidget {
  final SessionController session;
  const AadhaarNumberScreen({super.key, required this.session});

  @override
  State<AadhaarNumberScreen> createState() => _AadhaarNumberScreenState();
}

class _AadhaarNumberScreenState extends State<AadhaarNumberScreen> {
  final _aadhaar = TextEditingController();

  bool _loading = false;
  String? _error;

  // Theme State
  bool get _isDark => widget.session.isDark;
  
  void _update() {
    if (mounted) setState(() {});
  }
  
  // OTP Overlay State
  bool _showOtp = false;

  // Cooldown logic
  int _cooldown = 0; 
  DateTime? _cooldownEndsAt;
  Timer? _ticker;

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_update);
    // Listen to controller changes to update the custom placeholder
    _aadhaar.addListener(() {
      if (mounted) setState(() {});
    });
    _restoreCooldown();

    // Set full screen mode
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDark ? Brightness.light : Brightness.dark,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Auto-resume OTP if session exists
    if (widget.session.kycSessionUid != null && widget.session.kycSessionUid!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _showOtp = true);
      });
    }
  }

  Future<void> _restoreCooldown() async {
    final until = await widget.session.storage.getAadhaarCooldownUntil();
    if (until == null) return;

    final left = until.difference(DateTime.now()).inSeconds;
    if (left > 0) {
      await _startCooldown(left);
    } else {
      await widget.session.storage.clearAadhaarCooldownUntil();
    }
  }

  Future<void> _startCooldown(int seconds) async {
    if (seconds <= 0) return;
    _ticker?.cancel();
    final endsAt = DateTime.now().add(Duration(seconds: seconds));
    _cooldownEndsAt = endsAt;
    await widget.session.storage.saveAadhaarCooldownUntil(endsAt);

    if (!mounted) return;
    setState(() => _cooldown = seconds);

    _ticker = Timer.periodic(const Duration(seconds: 1), (t) async {
      final end = _cooldownEndsAt;
      if (end == null || !mounted) {
        t.cancel();
        return;
      }
      final left = end.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        t.cancel();
        _ticker = null;
        _cooldownEndsAt = null;
        await widget.session.storage.clearAadhaarCooldownUntil();
        if (!mounted) return;
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown = left);
      }
    });
  }

  String _prettyError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return "The service is taking too long to respond. Please check your internet or try again later.";
      }
      if (e.type == DioExceptionType.connectionError) {
        return "Cannot connect to our servers. Please check your internet connection.";
      }

      final data = e.response?.data;
      String? msg;
      if (data is Map) {
         msg = data['detail']?.toString() ?? data['message']?.toString() ?? data['reason']?.toString();
      }

      if (msg != null && msg.isNotEmpty) {
        // 1. Check for specific raw backend error patterns
        if (msg.contains("Surepass") && msg.contains("422")) {
           return "Invalid Aadhaar Number. Please check and try again.";
        }
        // 2. Return the actual error message
        return msg;
      }

      return "Network error (${e.response?.statusCode ?? 'unknown'}). Please try again.";
    }
    return "An unexpected error occurred. Please try again.";
  }

  void _showErrorPopup(String message, {String title = "Connection Issue", IconData icon = Icons.signal_wifi_off_rounded}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? const Color(0xFF161A22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: Colors.orangeAccent, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: _isDark ? Colors.white : const Color(0xFF1F2937),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: _isDark ? const Color(0xFF8B949E) : const Color(0xFF4B5563),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "OK",
              style: TextStyle(color: Color(0xFF3B3B7A), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }




  Future<void> _start() async {
    if (_cooldown > 0) return;

    final id = _digitsOnly(_aadhaar.text.trim());
    if (id.length != 12) {
      _showErrorPopup("Please enter a valid 12-digit Aadhaar number.", title: "Invalid Aadhaar", icon: Icons.error_outline_rounded);
      return;
    }

    widget.session.setLastAadhaarNumber(id);
    
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final res = await widget.session.api.dio.post(
        '/api/kyc/aadhaar/start/',
        data: {"id_number": id},
      );

      final data = res.data;
      final kycUid = (data is Map) ? data['kyc_session_uid']?.toString() : null;
      if (kycUid == null || kycUid.isEmpty) {
        throw Exception("Invalid server response: kyc_session_uid missing");
      }

      widget.session.kycSessionUid = kycUid;
      await widget.session.storage.saveKycSessionUid(kycUid);

      if (data is Map && data['retry_after_seconds'] != null) {
        final v = data['retry_after_seconds'];
        final wait = v is int ? v : int.tryParse(v.toString()) ?? 0;
        if (wait > 0) {
          await _startCooldown(wait);
        }
      }

      // Show OTP Overlay instead of navigating
      setState(() {
        _showOtp = true;
      });
       
    } catch (e) {
      String title = "Verification Failed";
      String msg = _prettyError(e);

      if (e is DioException) {
         if (e.response?.statusCode == 429) {
            title = "Too Many Attempts";
            msg = "You have exceeded the retry limit. Please wait a while before trying again.";
            int wait = 60; 
            final data = e.response?.data;
            if (data is Map && data['retry_after_seconds'] != null) {
              final v = data['retry_after_seconds'];
              wait = v is int ? v : int.tryParse(v.toString()) ?? wait;
            }
            await _startCooldown(wait);
         } else if (e.response?.statusCode == 400 || e.response?.statusCode == 422) {
             title = "Invalid Input";
             // Clean up generic server errors
             if (msg.contains("client_id")) msg = "Service unavailable. Please try again later.";
             if (msg.contains("surepass")) msg = "Verification service reported an issue. Please verify the number.";
         } else if (e.response?.statusCode == 500) {
             title = "Server Error";
             msg = "Something went wrong on our end. Please report this issue.";
         }
      }

      _showErrorPopup(msg, title: title, icon: title == "Connection Issue" ? Icons.signal_wifi_off_rounded : Icons.error_outline_rounded);
      
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_update);
    _ticker?.cancel();
    _aadhaar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors (Indigo/Blue for Aadhaar)
    final bg = _isDark ? const Color(0xFF0C0E11) : const Color(0xFFF5F7FA);
    final textMain = _isDark ? Colors.white : const Color(0xFF1F2937);
    final textSub = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final cardColor = _isDark ? const Color(0xFF161A22) : Colors.white;
    final borderColor = _isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    
    // Indigo Accent
    final accentColor = const Color(0xFF6366F1); // Indigo 500
    final inputBg = _isDark ? const Color(0xFF111318) : Colors.white;

    // Update status bar
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        
        if (_showOtp) {
          // If OTP sheet is showing, just hide it
          setState(() => _showOtp = false);
        } else {
          // Otherwise go back to KYC method select
          widget.session.setStage(OnboardingStage.chooseKycMethod);
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            // 1. The Main Content (Blurred when OTP is active)
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: _showOtp ? 10.0 : 0.0,
                sigmaY: _showOtp ? 10.0 : 0.0,
              ),
              child: Scaffold(
                backgroundColor: Colors.transparent, // Transparent to show outer bg
                body: SafeArea(
                  child: Column(
                    children: [
                      // -- Header --
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                             // Logo only (Back handled by system gesture)
                             Image.asset('assets/images/logo.png', height: 32),
                             
                             const Spacer(),
                             
                             // Theme & Logout
                             Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                  GlobalSupportButton(isDark: _isDark),
                                  IconButton(
                                    onPressed: () => widget.session.toggleTheme(),
                                    icon: Icon(
                                      _isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                                      color: textMain,
                                    ),
                                    tooltip: "Toggle Theme",
                                  ),
                                  IconButton(
                                    onPressed: () => widget.session.logout(),
                                    icon: Icon(Icons.logout_rounded, color: textMain),
                                    tooltip: "Logout",
                                  ),
                               ],
                             ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                const SizedBox(height: 32),
                                Text(
                                  "Aadhaar\nVerification",
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: textMain,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Please enter your 12-digit Aadhaar number to receive the verification OTP.",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textSub,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 48),
                                
                                // Identification Details Label
                                Text(
                                  "IDENTIFICATION DETAILS",
                                   style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor.withOpacity(0.8),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Input Field
                                Container(
                                  decoration: BoxDecoration(
                                    color: inputBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: borderColor),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Increased vertical padding
                                  child: Row(
                                    children: [
                                       Icon(Icons.fingerprint, color: accentColor, size: 32), // Increased Icon size
                                       const SizedBox(width: 16),
                                       Expanded(
                                         child: Stack(
                                           alignment: Alignment.centerLeft,
                                           children: [
                                              // 1. Background Placeholder (The "Mask")
                                              IgnorePointer(
                                                child: RichText(
                                                  text: TextSpan(
                                                    style: TextStyle(
                                                      color: textMain,
                                                      fontSize: 28, // Increased size
                                                      letterSpacing: 2.0,
                                                      fontFamily: 'RobotoMono', 
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    children: [
                                                      // Invisible text acting as spacer (matches what user typed)
                                                      TextSpan(
                                                        text: _aadhaar.text,
                                                        style: const TextStyle(color: Colors.transparent),
                                                      ),
                                                      // Visible remaining placeholder
                                                      TextSpan(
                                                        text: _aadhaar.text.length < "XXXX XXXX XXXX".length
                                                            ? "XXXX XXXX XXXX".substring(_aadhaar.text.length)
                                                            : "",
                                                        style: TextStyle(color: textSub.withOpacity(0.3)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // 2. Actual TextField
                                              TextField(
                                                controller: _aadhaar,
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                  AadhaarFormatter(),
                                                ],
                                                style: TextStyle(
                                                  color: textMain,
                                                  fontSize: 28, // Increased size
                                                  letterSpacing: 2.0,
                                                  fontFamily: 'RobotoMono', 
                                                  fontWeight: FontWeight.w500
                                                ),
                                                decoration: const InputDecoration(
                                                  border: InputBorder.none,
                                                  contentPadding: EdgeInsets.zero,
                                                  counterText: "",
                                                  isDense: true,
                                                ),
                                              ),
                                           ],
                                         ),
                                       )
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                Text(
                                  "Your data is encrypted and securely processed via UIDAI.",
                                  style: TextStyle(
                                     color: textSub.withOpacity(0.6),
                                     fontSize: 12,
                                     fontStyle: FontStyle.italic,
                                  ),
                                ),
  
                                if (_error != null) ...[
                                  const SizedBox(height: 24),
                                   Center(
                                     child: Text(
                                       _error!,
                                       style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                                       textAlign: TextAlign.center,
                                     ),
                                   ),
                                ],
                                
                                if (_cooldown > 0) ...[
                                   const SizedBox(height: 16),
                                   Center(
                                     child: Text(
                                       "Wait ${_cooldown}s to retry",
                                       style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                     ),
                                   ),
                                ]
                             ],
                          ),
                        ),
                      ),
                      
                      // Bottom Button
                      Padding(
                         padding: const EdgeInsets.all(24),
                         child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: (_loading || _cooldown > 0) ? null : _start,
                              style: ElevatedButton.styleFrom(
                                 backgroundColor: accentColor,
                                 foregroundColor: Colors.white,
                                 disabledBackgroundColor: accentColor.withOpacity(0.5),
                                 elevation: 0,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _loading 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text("Send Aadhaar OTP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 20)
                                    ],
                                  )
                            ),
                         ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
  
            // 2. The OTP Sheet Overlay
            if (_showOtp)
              Container(color: Colors.black.withOpacity(0.3)), // Additional dimming
  
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: _showOtp ? 0 : -600, // Slide up/down
              child: _showOtp 
                ? AadhaarOtpSheet(
                    session: widget.session, 
                    // isDark removed
                    onClose: () async {
                      setState(() => _showOtp = false);
                      await widget.session.resetKyc();
                    },
                  ) 
                : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Formatter for XXXX XXXX XXXX
class AadhaarFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 12) return oldValue; // Limit 12 digits

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    
    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
