import 'dart:async';
import 'dart:ui'; // For ImageFilter
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/session_controller.dart';
import '../../app/onboarding_stage.dart';
import 'aadhaar_otp_screen.dart'; // Import Sheet Widget

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
  bool _isDark = true;
  
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
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      if (data is Map && data['reason'] != null) return data['reason'].toString();
      return "Network/API error (${e.response?.statusCode ?? 'no status'})";
    }
    return e.toString();
  }

  Future<void> _start() async {
    if (_cooldown > 0) return;

    final id = _digitsOnly(_aadhaar.text.trim());
    widget.session.setLastAadhaarNumber(id);

    if (id.length != 12) {
      setState(() => _error = "Please enter a valid 12-digit Aadhaar number");
      return;
    }

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
      if (e is DioException && e.response?.statusCode == 429) {
        int wait = 60; 
        final data = e.response?.data;
        if (data is Map && data['retry_after_seconds'] != null) {
          final v = data['retry_after_seconds'];
          wait = v is int ? v : int.tryParse(v.toString()) ?? wait;
        }
        await _startCooldown(wait);
        setState(() => _error = "Rate limited. Please wait ${wait}s and try again.");
      } else {
        setState(() => _error = _prettyError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
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

    return Scaffold(
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
                           // Back Button
                           IconButton(
                             onPressed: () {
                                if (_showOtp) {
                                  setState(() => _showOtp = false);
                                } else {
                                  widget.session.setStage(OnboardingStage.chooseKycMethod);
                                }
                             },
                             icon: Icon(Icons.arrow_back_ios_new, size: 20, color: textMain),
                           ),
                           
                           const Spacer(),
                           
                           // Theme & Logout
                           Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                                IconButton(
                                  onPressed: () => setState(() => _isDark = !_isDark),
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
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                child: Row(
                                  children: [
                                     Icon(Icons.fingerprint, color: accentColor, size: 28),
                                     const SizedBox(width: 16),
                                     Expanded(
                                       child: TextField(
                                         controller: _aadhaar,
                                         keyboardType: TextInputType.number,
                                         inputFormatters: [
                                           FilteringTextInputFormatter.digitsOnly,
                                           LengthLimitingTextInputFormatter(12),
                                         ],
                                         style: TextStyle(
                                           color: textMain,
                                           fontSize: 18, 
                                           letterSpacing: 2.0,
                                           fontFamily: 'RobotoMono', 
                                           fontWeight: FontWeight.w500
                                         ),
                                         decoration: InputDecoration(
                                           border: InputBorder.none,
                                           hintText: "0000 0000 0000",
                                           hintStyle: TextStyle(
                                             color: textSub.withOpacity(0.3),
                                             letterSpacing: 2.0,
                                           ),
                                         ),
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
                  isDark: _isDark,
                  onClose: () async {
                    setState(() => _showOtp = false);
                    await widget.session.resetKyc();
                  },
                ) 
              : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
