import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app/session_controller.dart';
import '../../app/onboarding_stage.dart';
import '../../widgets/global_support_button.dart';

class AadhaarOtpSheet extends StatefulWidget {
  final SessionController session;
  final VoidCallback onClose;

  const AadhaarOtpSheet({
    super.key, 
    required this.session,
    required this.onClose,
  });

  @override
  State<AadhaarOtpSheet> createState() => _AadhaarOtpSheetState();
}

class _AadhaarOtpSheetState extends State<AadhaarOtpSheet> {
  final _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = false;
  bool _resendLoading = false;
  String? _error;

  int _attempts = 0;
  static const int _maxAttempts = 5;

  // cooldown for resend / rate-limit
  int _cooldown = 0; // seconds left
  DateTime? _cooldownEndsAt;
  Timer? _ticker;

  // Theme State
  bool get _isDark => widget.session.isDark;

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_update);
    _restoreCooldown();
    // Auto-focus logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  // Removed didUpdateWidget since we use listener

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
        return "The verification service is taking too long to respond. Please check your internet or try again later.";
      }
      if (e.type == DioExceptionType.connectionError) {
        return "Cannot connect to the verification service. Please check your internet connection.";
      }

      final data = e.response?.data;
      String? msg;
      if (data is Map) {
         msg = data['detail']?.toString() ?? data['message']?.toString() ?? data['reason']?.toString();
      }
      
      if (msg != null && msg.isNotEmpty) {
        // 1. Check for specific raw backend error patterns
        if (msg.contains("Surepass") && msg.contains("422")) {
           if (msg.contains("verification_failed") || msg.contains("Verification Failed")) {
             return "Invalid OTP. Please check and enter the correct code.";
           }
           return "Invalid details provided. Please check and try again.";
        }
        
        // 2. Return the actual error message otherwise
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

  Future<void> _submit() async {
    if (_attempts >= _maxAttempts) {
      setState(() => _error = "Too many wrong attempts. Please resend OTP.");
      return;
    }

    final kycUid = widget.session.kycSessionUid;
    if (kycUid == null || kycUid.isEmpty) {
      setState(() => _error = "KYC session missing. Restart Aadhaar verification.");
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _error = "Please enter the full 6-digit OTP");
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final res = await widget.session.api.dio.post(
        '/api/kyc/aadhaar/submit-otp/',
        data: {"kyc_session_uid": kycUid, "otp": otp},
      );

      _attempts = 0;
      final data = res.data;
      final next = data is Map ? data['next']?.toString() : null;
      final aadhaarDetails = data is Map ? data['aadhaar_details'] : null;
      
      if (aadhaarDetails is Map) {
        await widget.session.setAadhaarDetails(Map<String, dynamic>.from(aadhaarDetails));
      }
      
      if (next == "VERIFY_DETAILS") {
        widget.session.setStage(OnboardingStage.verifyDetails);
      } else {
        await widget.session.bootstrap();
      }
    } catch (e) {
      if (e is DioException) {
        final data = e.response?.data;
        final code = data is Map ? data['code']?.toString() : null;
        if (code == 'RESTART_REQUIRED' || e.response?.statusCode == 429) {
          await widget.session.resetKyc();
          return;
        }
      }
      _attempts += 1;
      _showErrorPopup("${_prettyError(e)} (Attempt $_attempts/$_maxAttempts)", 
        title: (e is DioException && (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout)) ? "Connection Issue" : "Verification Failed",
        icon: (e is DioException && (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout)) ? Icons.signal_wifi_off_rounded : Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    
    final idNumber = widget.session.lastAadhaarNumber;
    if (idNumber == null || idNumber.isEmpty) {
      setState(() => _error = "Aadhaar number missing. Please restart verification.");
      return;
    }

    setState(() {
      _error = null;
      _resendLoading = true;
    });

    try {
      final res = await widget.session.api.dio.post(
        '/api/kyc/aadhaar/resend/', 
        data: {"id_number": idNumber}
      );

      final data = res.data;
      if (data is Map && data['kyc_session_uid'] != null) {
        final uid = data['kyc_session_uid'].toString();
        widget.session.kycSessionUid = uid;
        await widget.session.storage.saveKycSessionUid(uid);
      }

      int wait = 60;
      if (data is Map && data['retry_after_seconds'] != null) {
        final v = data['retry_after_seconds'];
        wait = v is int ? v : int.tryParse(v.toString()) ?? 60;
      }
      await _startCooldown(wait);

      setState(() {
        _attempts = 0;
        _error = "OTP resent. Please check your mobile.";
      });
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 429) {
        int wait = 60;
        final data = e.response?.data;
        if (data is Map && data['retry_after_seconds'] != null) {
          final v = data['retry_after_seconds'];
          wait = v is int ? v : int.tryParse(v.toString()) ?? 60;
        }
        await _startCooldown(wait);
        _showErrorPopup("Rate limited. Please wait ${wait}s and try again.", title: "Too Many Attempts", icon: Icons.timer_outlined);
      } else {
        final msg = _prettyError(e);
        _showErrorPopup(msg, 
          title: (e is DioException && (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout)) ? "Connection Issue" : "Verification Error",
          icon: (e is DioException && (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout)) ? Icons.signal_wifi_off_rounded : Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _resendLoading = false);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_update);
    _ticker?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? const Color(0xFF161A22) : Colors.white,
        title: Text(
          "Cancel Verification?", 
          style: TextStyle(
            color: _isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold
          )
        ),
        content: Text(
          "Are you sure you want to cancel? You will need to request a new OTP.",
          style: TextStyle(
            color: _isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldClose == true) {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Shared Theme Variables 
    final bg = _isDark ? const Color(0xFF161A22) : Colors.white; // Sheet color
    final textMain = _isDark ? Colors.white : const Color(0xFF1F2937);
    final textSub = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    // Indigo accent for Aadhaar
    final accentColor = const Color(0xFF6366F1); 

    final inputBg = _isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100];
    final activeBorder = accentColor;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24), // Explicit padding
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle / Close
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GlobalSupportButton(isDark: _isDark),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _handleClose, // Intercept close
                  icon: Icon(Icons.close, color: textSub, size: 28), // Slightly larger
                  style: IconButton.styleFrom(
                    backgroundColor: _isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          
          Text(
            "Verify Aadhaar OTP",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textMain,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            "Please enter the 6-digit verification code sent to your Aadhaar-linked mobile number.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textSub,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // -- 6-Digit Input Row --
          Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final text = _otpController.text;
                  final char = index < text.length ? text[index] : "";
                  final isActive = index == text.length;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 42,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? activeBorder : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      char,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                    ),
                  );
                }),
              ),
              // Hidden TextField for Focus
               Positioned.fill(
                 child: Opacity(
                   opacity: 0,
                   child: TextField(
                     controller: _otpController,
                     focusNode: _focusNode,
                     keyboardType: TextInputType.number,
                     maxLength: 6,
                     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                     onChanged: (_) => setState(() {}),
                     decoration: const InputDecoration(border: InputBorder.none, counterText: ""),
                   ),
                 ),
               ),
            ],
          ),


          // const SizedBox(height: 24), // Removed inline error padding

          // Resend Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Didn't receive the code? ", style: TextStyle(color: textSub, fontSize: 14)),
              
              if (_cooldown == 0)
                GestureDetector(
                  onTap: _resendLoading ? null : _resend,
                  child: _resendLoading 
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))
                    : Text(
                        "Resend",
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold, 
                          fontSize: 14,
                        ),
                      ),
                )
              else
                 Text(
                   "Resend in ${_cooldown}s",
                   style: TextStyle(
                     color: textSub,
                     fontWeight: FontWeight.w500,
                     fontSize: 14
                   ),
                 ),
            ],
          ),
          
          const SizedBox(height: 8),
          if (_attempts > 0)
            Text("Attempts: $_attempts/$_maxAttempts", style: TextStyle(color: textSub, fontSize: 12)),
          
          const SizedBox(height: 32),

          // Bottom CTA
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                 backgroundColor: accentColor,
                 foregroundColor: Colors.white,
                 disabledBackgroundColor: accentColor.withOpacity(0.5),
                 elevation: 0,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Verify Aadhaar OTP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// Wrapper class for routing if needed independently
class AadhaarOtpScreen extends StatelessWidget {
  final SessionController session;
  const AadhaarOtpScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: AadhaarOtpSheet(
           session: session,
           onClose: () async {
             await session.resetKyc();
             // resetKyc sets stage to aadhaarNumber, router should handle it
           },
        ),
      ),
    );
  }
}
