import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/session_controller.dart';
import '../../app/onboarding_stage.dart';

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
  bool _isDark = true;

  @override
  void initState() {
    super.initState();
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
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      if (data is Map && data['reason'] != null) return data['reason'].toString();
      return "Network/API error (${e.response?.statusCode ?? 'no status'})";
    }
    return e.toString();
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
               primary: Color(0xFF9C27B0), // Purple primary
               onPrimary: Colors.white,
               surface: Color(0xFF1E2030),
               onSurface: Colors.white,
            ),
             dialogBackgroundColor: const Color(0xFF161A22),
          ) : ThemeData.light().copyWith(
             colorScheme: const ColorScheme.light(
               primary: Color(0xFF9C27B0), // Purple primary
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
      final kycUid = (data is Map) ? data['kyc_session_uid']?.toString() : null;
      if (kycUid == null || kycUid.isEmpty) {
        throw Exception("Invalid server response: kyc_session_uid missing");
      }

      widget.session.kycSessionUid = kycUid;
      await widget.session.storage.saveKycSessionUid(kycUid);

      final next = data is Map ? data['next']?.toString() : null;

      if (next == "VERIFY_DETAILS") {
        widget.session.setStage(OnboardingStage.verifyDetails);
      } else {
        await widget.session.bootstrap();
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 429) {
        setState(() => _error = "Rate limited. Please wait and try again.");
      } else {
        setState(() => _error = _prettyError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
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
    
    // Changed to a deeper Violet/Purple to avoid "Pink" look
    final accentColor = const Color(0xFF7C3AED); // Violet 600
    final accentBg = const Color(0xFFEDE9FE); 
    
    final infoBg = _isDark ? const Color(0xFF1E2030) : const Color(0xFFEBEBFF); // Info Box
    final infoText = _isDark ? const Color(0xFFB0B0E0) : const Color(0xFF4A4A8A);

    // Update status bar on build in case theme changed
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // -- Header --
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                   // Back Button (Logic Fixed)
                   IconButton(
                     onPressed: () {
                        // Use session stage management instead of Navigator.pop
                        widget.session.setStage(OnboardingStage.chooseKycMethod);
                     },
                     icon: Icon(Icons.arrow_back_ios_new, size: 20, color: textMain),
                   ),
                   
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
                  children: [
                    const SizedBox(height: 24),
                    // Shield Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                         color: _isDark ? accentColor.withOpacity(0.1) : accentBg,
                         shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.security, color: accentColor, size: 36),
                    ),
                    const SizedBox(height: 24),
                    
                    // Title
                    Text(
                      "Verify Identity",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Securely link your driving license to access the elite operator portal.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: textSub,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // -- Input 1: License Number --
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "DRIVING LICENSE NUMBER",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
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
                          letterSpacing: 0.5,
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
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
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
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    );
  }
}

