import 'dart:ui'; // For ImageFilter
import 'package:flutter/services.dart'; // Import for input formatters
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/session_controller.dart';
import '../../app/router.dart';
import 'otp_verify_screen.dart'; // Helper widget

class MobileNumberScreen extends StatefulWidget {
  final SessionController session;
  const MobileNumberScreen({super.key, required this.session});

  @override
  State<MobileNumberScreen> createState() => _MobileNumberScreenState();
}

class _MobileNumberScreenState extends State<MobileNumberScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  
  // Theme State
  bool get _isDark => widget.session.isDark;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }
  
  // OTP Overlay State
  bool _showOtp = false;

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  String _prettyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      return "Network/API error (${e.response?.statusCode ?? 'no status'})";
    }
    return e.toString();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    final mobile = _digitsOnly(_controller.text.trim());
    
    // VALIDATION: 10 Digits & Indian Regex
    if (mobile.length != 10) {
       setState(() {
        _loading = false;
        _error = "Please enter a valid 10-digit number";
      });
      return;
    }

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      setState(() {
        _loading = false;
        _error = "Invalid Indian mobile number (must start with 6-9)";
      });
      return;
    }

    try {
      await widget.session.storage.saveMobile(mobile);
      widget.session.mobile = mobile;

      final res = await widget.session.api.dio.post(
        '/api/identity/operator/otp/request/',
        data: {"mobile": mobile},
      );

      final data = res.data;
      final otpSessionUid = (data is Map) ? data['otp_session_uid']?.toString() : null;
      if (otpSessionUid == null || otpSessionUid.isEmpty) {
        throw Exception("Invalid server response: otp_session_uid missing");
      }

      widget.session.otpSessionUid = otpSessionUid;

      // SUCCESS: Show OTP Overlay
      setState(() {
        _showOtp = true;
      });

    } catch (e) {
      setState(() => _error = _prettyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_update);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Colors based on _isDark
    final backgroundColor = _isDark ? const Color(0xFF0C0E11) : const Color(0xFFF5F7FA);
    final cardColor = _isDark ? const Color(0xFF161A22) : Colors.white;
    final primaryColor = const Color(0xFF3B3B7A);
    final textColor = _isDark ? Colors.white : const Color(0xFF1F2937);
    final subTextColor = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final borderColor = _isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    final inputTextColor = _isDark ? Colors.white : Colors.black87;
    final hintColor = _isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.3);

    // Navbar style
    SystemChrome.setSystemUIOverlayStyle(_isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 1. The Login UI (Blurred if OTP is showing)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _showOtp ? 10.0 : 0.0,
              sigmaY: _showOtp ? 10.0 : 0.0,
            ),
            child: Scaffold( // Inner scaffold to maintain layout
              backgroundColor: Colors.transparent, 
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                centerTitle: false,
                title: Image.asset(
                  'assets/images/logo.png',
                  height: 40,
                ),
                actions: [
                   IconButton(
                      onPressed: () => widget.session.toggleTheme(),
                      icon: Icon(
                        _isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                        color: textColor,
                      ),
                      tooltip: "Toggle Theme",
                    ),
                    const SizedBox(width: 8),
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              
                              // -- Header --
                              Text(
                                "Welcome Back!",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Enter your 10-digit mobile number. We'll send a 6-digit OTP to verify your account.",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: subTextColor,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 40),

                              // -- Input Field --
                              Container(
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor),
                                  boxShadow: _isDark ? [] : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      "Mobile Number",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subTextColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        // Flag & Code
                                        const Text(
                                          "🇮🇳",
                                          style: TextStyle(fontSize: 24),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "+91",
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Divider
                                        Container(
                                          width: 1,
                                          height: 24,
                                          color: borderColor,
                                        ),
                                        const SizedBox(width: 12),
                                        // Text Field
                                        Expanded(
                                          child: TextField(
                                            controller: _controller,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              LengthLimitingTextInputFormatter(10),
                                            ],
                                            style: TextStyle(
                                              color: inputTextColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 1.2,
                                            ),
                                            cursorColor: primaryColor,
                                            decoration: InputDecoration(
                                              hintText: "00000 00000",
                                              hintStyle: TextStyle(
                                                color: hintColor,
                                                fontSize: 18,
                                                letterSpacing: 1.2,
                                              ),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                              counterText: "",
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "ENTER 10-DIGIT NUMBER",
                                style: TextStyle(
                                  color: _isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),

                              // -- Error Message --
                              if (_error != null) ...[
                                const SizedBox(height: 24),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.red.withOpacity(0.1),
                                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // -- Center Shield Icon (Background Element) --
                              const Spacer(),

                              const Spacer(),

                              // -- Button --
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _sendOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: _isDark ? 0 : 4,
                                    shadowColor: primaryColor.withOpacity(0.3),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Send OTP",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded, size: 20),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 24),
                              // -- Trouble Logging In? --
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                  },
                                  child: Text(
                                    "TROUBLE LOGGING IN?",
                                    style: TextStyle(
                                      color: _isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
              ? OtpVerifySheet(
                  session: widget.session, 
                  // isDark removed, handled internally
                  onClose: () => setState(() => _showOtp = false),
                ) 
              : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
