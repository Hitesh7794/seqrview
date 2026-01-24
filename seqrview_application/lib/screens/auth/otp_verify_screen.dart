import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/session_controller.dart';

class OtpVerifySheet extends StatefulWidget {
  final SessionController session;
  final VoidCallback onClose;
  
  const OtpVerifySheet({
    super.key, 
    required this.session,
    required this.onClose,
  });

  @override
  State<OtpVerifySheet> createState() => _OtpVerifySheetState();
}

class _OtpVerifySheetState extends State<OtpVerifySheet> {
  final _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _loading = false;
  bool _resendLoading = false;
  String? _error;

  // Timer State
  Timer? _timer;
  int _secondsRemaining = 59;
  bool _canResend = false;

  // Theme State
  bool get _isDark => widget.session.isDark;

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_update);
    _startTimer();
    // Auto-focus the hidden input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 59;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() {
          _canResend = true;
          _timer?.cancel();
        });
      }
    });
  }

  String _prettyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      return "Network/API error (${e.response?.statusCode ?? 'no status'})";
    }
    return e.toString();
  }

  Future<void> _verify() async {
    final otpSessionUid = widget.session.otpSessionUid;
    if (otpSessionUid == null || otpSessionUid.isEmpty) {
      setState(() => _error = "OTP session missing. Please request OTP again.");
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _error = "Please enter the full 6-digit code");
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final res = await widget.session.api.dio.post(
        '/api/identity/operator/otp/verify/',
        data: {"otp_session_uid": otpSessionUid, "otp": otp},
      );

      final data = res.data;
      if (data is! Map) throw Exception("Invalid server response");

      final tokens = data['tokens'];
      if (tokens is! Map) throw Exception("Tokens missing in response");

      final access = tokens['access']?.toString();
      final refresh = tokens['refresh']?.toString();
      if (access == null || refresh == null || access.isEmpty || refresh.isEmpty) {
        throw Exception("Invalid tokens received");
      }

      await widget.session.storage.saveTokens(access: access, refresh: refresh);
      widget.session.otpSessionUid = null;

      await widget.session.bootstrap(); // router auto-redirect
    } catch (e) {
      setState(() => _error = _prettyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;

    final mobile = widget.session.mobile;
    if (mobile == null || mobile.isEmpty) {
      setState(() => _error = "Mobile missing. Please go back.");
      return;
    }

    setState(() {
      _error = null;
      _resendLoading = true;
    });

    try {
      final res = await widget.session.api.dio.post(
        '/api/identity/operator/otp/request/',
        data: {"mobile": mobile},
      );

      final data = res.data;
      final otpSessionUid = (data is Map) ? data['otp_session_uid']?.toString() : null;
      if (otpSessionUid == null || otpSessionUid.isEmpty) {
        throw Exception("Invalid server response");
      }
      widget.session.otpSessionUid = otpSessionUid;

      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OTP Resent!")),
      );
    } catch (e) {
      setState(() => _error = _prettyError(e));
    } finally {
      setState(() => _resendLoading = false);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_update);
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Styling
    final bg = _isDark ? const Color(0xFF161A22) : Colors.white; // Card color
    final textMain = _isDark ? Colors.white : const Color(0xFF1F2937);
    final textSub = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final accent = const Color(0xFF7C4DFF); // Deep Purple

    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Wrap content
        children: [
          // Drag Handle / Close
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.close, color: textSub),
                onPressed: widget.onClose,
              )
            ],
          ),
          
          Text(
            "Verify OTP",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textMain,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            "Please enter the 6-digit verification code sent to your registered mobile number.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textSub,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // -- OTP Input Area --
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final text = _otpController.text;
                    final char = index < text.length ? text[index] : "";
                    final isActive = index == text.length;
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 45,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        char,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                    );
                  }),
                ),
                Positioned.fill(
                  child: TextField(
                    controller: _otpController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.transparent),
                    decoration: const InputDecoration(
                      counterText: "",
                      border: InputBorder.none,
                      fillColor: Colors.transparent, 
                      filled: true,
                    ),
                    cursorColor: Colors.transparent,
                    showCursor: false,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          if (_error != null)
           Padding(
             padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
             child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
           ),

          const SizedBox(height: 32),

          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text(
                      "Verify",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),
          
          // Resend Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Didn't receive the code? ", style: TextStyle(color: textSub, fontSize: 14)),
              
              if (_canResend)
                GestureDetector(
                  onTap: _resendLoading ? null : _resend,
                  child: Text(
                    "Resend",
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold, 
                      fontSize: 14,
                    ),
                  ),
                )
              else
                 Text(
                   "Resend in ${_secondsRemaining}s",
                   style: TextStyle(
                     color: textSub,
                     fontWeight: FontWeight.w500,
                     fontSize: 14
                   ),
                 ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Wrapper class to maintain router compatibility
class OtpVerifyScreen extends StatelessWidget {
  final SessionController session;
  const OtpVerifyScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: OtpVerifySheet(
          session: session,
          onClose: () {
             if (Navigator.canPop(context)) {
               Navigator.pop(context);
             } else {
               // Fallback if accessed directly
               context.go('/auth/mobile');
             }
          },
        ),
      ),
    );
  }
}
