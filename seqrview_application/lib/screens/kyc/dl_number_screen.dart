import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/session_controller.dart';
import '../../app/onboarding_stage.dart';
import '../../widgets/global_support_button.dart';

class DLNumberScreen extends StatefulWidget {
  final SessionController session;
  const DLNumberScreen({super.key, required this.session});

  @override
  State<DLNumberScreen> createState() => _DLNumberScreenState();
}

class _DLNumberScreenState extends State<DLNumberScreen> {
  final _licenseNumber = TextEditingController();
  DateTime? _dob;
  final _dobController = TextEditingController(); // For visual display

  bool _loading = false;
  String? _error;

  // Theme State
  bool get _isDark => widget.session.isDark;

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_update);
     // Set full screen mode
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDark ? Brightness.light : Brightness.dark,
      ),
    );
     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
           return "Invalid Driving License or Date of Birth. Please check and try again.";
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

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$day / $m / $y"; // Display format dd/mm/yyyy
  }
  
  String _apiDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day"; // API format yyyy-mm-dd
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime(now.year - 15, 12, 31),
      builder: (context, child) {
        return Theme(
          data: _isDark ? ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
               primary: Color(0xFF6366F1), // Indigo primary
               onPrimary: Colors.white,
               surface: Color(0xFF1E2030),
               onSurface: Colors.white,
            ),
             dialogBackgroundColor: const Color(0xFF161A22),
          ) : ThemeData.light().copyWith(
             colorScheme: const ColorScheme.light(
               primary: Color(0xFF6366F1), // Indigo primary
               onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
         _dob = picked;
         _dobController.text = _fmtDate(picked);
      });
    }
  }

  Future<void> _start() async {
    // 1. Remove hyphens/spaces to handle formatting
    String licenseNumber = _licenseNumber.text.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (licenseNumber.isEmpty) {
      setState(() => _error = "Please enter your driving license number");
      return;
    }

    // 2. Validate format: 
    // Starts with 2 letters (State Code)
    // Followed by 11 to 18 alphanumeric characters (handling various state formats like RJ14D...)
    // Total length: 13 to 20 characters
    final dlRegex = RegExp(r"^[A-Z]{2}[A-Z0-9]{11,18}$");
    if (!dlRegex.hasMatch(licenseNumber)) {
      setState(() => _error = "Invalid DL format. Please double check your number.");
      return;
    }

    if (_dob == null) {
      setState(() => _error = "Please select your date of birth");
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final res = await widget.session.api.dio.post(
        '/api/kyc/dl/start/',
        data: {
          "license_number": licenseNumber,
          "dob": _apiDate(_dob!),
        },
      );

      final data = res.data;
      debugPrint("DEBUG: DL Start Response Data Type: ${data.runtimeType}");
      
      final kycUid = (data is Map) ? data['kyc_session_uid']?.toString() : null;
      if (kycUid == null || kycUid.isEmpty) {
        throw Exception("Invalid server response: kyc_session_uid missing");
      }

      await widget.session.setKycSessionUid(kycUid);

      // Save DL details for auto-fill on Verify Details screen
      if (data is Map && data['aadhaar_details'] != null) {
        final details = Map<String, dynamic>.from(data['aadhaar_details']);
        debugPrint("DEBUG: DL details found in response, setting in session");
        await widget.session.setAadhaarDetails(details);
      } else {
        debugPrint("DEBUG: WARNING! aadhaar_details missing in DL Start response");
      }

      // Always proceed to Verify Details after successful start
      widget.session.tempDob = _dob; // Save DOB for next screen
      debugPrint("DEBUG: Moving to verifyDetails stage. tempDob=$_dob");
      widget.session.setStage(OnboardingStage.verifyDetails);
    } catch (e) {
      final msg = _prettyError(e);
      setState(() => _error = msg);
      _showErrorPopup(msg, title: (e is DioException && (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout)) ? "Connection Issue" : "Verification Error", icon: (e is DioException && (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout)) ? Icons.signal_wifi_off_rounded : Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_update);
    _licenseNumber.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors (Adjusted to avoid Pink)
    final bg = _isDark ? const Color(0xFF0C0E11) : const Color(0xFFF5F7FA);
    final textMain = _isDark ? Colors.white : const Color(0xFF1F2937);
    final textSub = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final cardColor = _isDark ? const Color(0xFF161A22) : Colors.white;
    final borderColor = _isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    
    // Indigo Accent (Matches Aadhaar)
    final accentColor = const Color(0xFF6366F1); // Indigo 500
    final inputBg = _isDark ? const Color(0xFF111318) : Colors.white; 
    
    final infoBg = _isDark ? const Color(0xFF1E2030) : const Color(0xFFEBEBFF); // Info Box
    final infoText = _isDark ? const Color(0xFFB0B0E0) : const Color(0xFF4A4A8A);

    // Update status bar on build in case theme changed
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
        widget.session.setStage(OnboardingStage.chooseKycMethod);
      },
      child: Scaffold(
      backgroundColor: bg,
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
                   
                   // Center Title/Progress
                   Expanded(
                     child: Center(
                       child: const SizedBox(),
                     ),
                   ),
                   
                   // Theme & Logout
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
                    
                    // Title
                    Text(
                      "Driving License\nVerification",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Securely link your driving license to access the elite operator portal.",
                      style: TextStyle(
                        fontSize: 16,
                        color: textSub,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // -- Input 1: License Number --
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "DRIVING LICENSE NUMBER",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: TextField(
                        controller: _licenseNumber,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(color: textMain, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: "MH-1220230004567",
                          hintStyle: TextStyle(color: textSub.withOpacity(0.5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          suffixIcon: Icon(Icons.badge_outlined, color: textSub.withOpacity(0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // -- Input 2: Date of Birth --
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "DATE OF BIRTH",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                         if (!_loading) _pickDob();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _dobController,
                             style: TextStyle(color: textMain, fontWeight: FontWeight.w500),
                             decoration: InputDecoration(
                              hintText: "DD / MM / YYYY",
                              hintStyle: TextStyle(color: textSub.withOpacity(0.5)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              suffixIcon: Icon(Icons.calendar_month_outlined, color: textSub.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // -- Info Box --
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: infoBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: infoText.withOpacity(0.1)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info, color: infoText, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Ensure the details match your government-issued ID exactly to avoid delays in verification.",
                              style: TextStyle(color: infoText, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                         _error!,
                         style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                         textAlign: TextAlign.center,
                      ),
                    ]
                  ],
                ),
              ),
            ),
             
            // Bottom Area
            Padding(
               padding: const EdgeInsets.all(24),
               child: Column(
                 children: [
                    // TextButton(
                    //   onPressed: () {},
                    //   child: Text(
                    //     "Why do we need this?",
                    //     style: TextStyle(
                    //        decoration: TextDecoration.underline,
                    //        color: accentColor,
                    //        fontSize: 14,
                    //        fontWeight: FontWeight.w600
                    //     )
                    //   ),
                    // ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _start,
                        style: ElevatedButton.styleFrom(
                           backgroundColor: accentColor,
                           foregroundColor: Colors.white,
                           disabledBackgroundColor: accentColor.withOpacity(0.5),
                           elevation: 0,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _loading 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Confirm & Verify", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                      ),
                    ),
                    const SizedBox(height: 16),
                     Text(
                        "By proceeding, you agree to our verification terms and data privacy policy.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                           color: textSub.withOpacity(0.5),
                           fontSize: 10,
                        ),
                     ),
                 ],
               ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

