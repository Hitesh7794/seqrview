import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app/session_controller.dart';
import '../../app/onboarding_stage.dart';
import '../../widgets/global_support_button.dart';

class AadhaarVerifyDetailsScreen extends StatefulWidget {
  final SessionController session;
  
  const AadhaarVerifyDetailsScreen({
    super.key,
    required this.session,
  });

  @override
  State<AadhaarVerifyDetailsScreen> createState() => _AadhaarVerifyDetailsScreenState();
}

class _AadhaarVerifyDetailsScreenState extends State<AadhaarVerifyDetailsScreen> {
  final _fullName = TextEditingController();
  final _dobController = TextEditingController();
  final _address = TextEditingController();
  DateTime? _dob;
  String? _gender;
  String? _selectedState;
  String? _selectedDistrict;
  String? _profileZip;

  bool _loading = false;
  bool _isDL = false;
  bool _methodChecked = false; // Prevent multiple checks
  String? _error;
  
  // Auto-fill status
  bool _didAutoFill = false;
  bool _consentToUseAadhaarData = false;
  bool _hasAadhaarData = false;

  // Global Theme
  bool get _isDark => widget.session.isDark;
  
  void _update() {
    if (mounted) {
      debugPrint("DEBUG: _update: hasData=$_hasAadhaarData, details=${widget.session.aadhaarDetails != null}");
      if (!_hasAadhaarData && widget.session.aadhaarDetails != null && widget.session.aadhaarDetails!.isNotEmpty) {
        debugPrint("DEBUG: _update: Data detected, running auto-fill");
        _runAutoFill();
      }
      setState(() {});
    }
  }
  
  // Helper for date formatting
  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
  }

  // Display format (DD-MM-YYYY)
  String _fmtDateDisplay(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$day-$m-$y";
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
         msg = data['detail']?.toString() ?? data['message']?.toString();
      }
      
      if (msg != null && msg.isNotEmpty) {
        // 1. Check for specific raw backend error patterns
        if (msg.contains("Surepass") && msg.contains("422")) {
           return "Invalid details provided. Please check and try again.";
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

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_update);
    
    // Initial check for method to set _isDL correctly from the start
    _checkMethod();
    
    // Run initial auto-fill - immediately and then after a brief delay to handle session sync
    _runAutoFill();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_hasAadhaarData) {
        debugPrint("DEBUG: Retrying auto-fill after 300ms delay...");
        _runAutoFill();
      }
    });

    // Check tempDob specially for DL
    if (widget.session.tempDob != null) {
      debugPrint("DEBUG: Found tempDob in initState: ${widget.session.tempDob}");
      setState(() {
         _dob = widget.session.tempDob;
         _dobController.text = _fmtDateDisplay(_dob!);
         _isDL = true; // High confidence it's DL if tempDob is present
      });
    }
  }
  
  void _runAutoFill() {
    final data = widget.session.aadhaarDetails;
    debugPrint("DEBUG: _runAutoFill: Session Data present? ${data != null}, size: ${data?.length}");
    
    if (data == null || data.isEmpty) {
       debugPrint("DEBUG: _runAutoFill: No data found in session details");
       return;
    }

    _applyData(data);
  }
  
  void _applyData(Map<String, dynamic> data) {
    debugPrint("DEBUG: _applyData: Applying data to UI: $data");

    // Mapping for common abbreviations
    final stateAlias = {
      'UP': 'Uttar Pradesh', 'MP': 'Madhya Pradesh', 'AP': 'Andhra Pradesh',
      'TN': 'Tamil Nadu', 'KL': 'Kerala', 'MH': 'Maharashtra',
      'GJ': 'Gujarat', 'RJ': 'Rajasthan', 'KA': 'Karnataka',
      'WB': 'West Bengal', 'DL': 'Delhi', 'RAJ': 'Rajasthan',
      'HR': 'Haryana', 'PB': 'Punjab', 'TS': 'Telangana',
      'TG': 'Telangana', 'UK': 'Uttarakhand', 'UA': 'Uttarakhand',
      'HP': 'Himachal Pradesh', 'JK': 'Jammu and Kashmir',
      'CT': 'Chhattisgarh', 'CG': 'Chhattisgarh', 'GA': 'Goa',
      'AR': 'Arunachal Pradesh', 'AS': 'Assam', 'BR': 'Bihar',
      'JH': 'Jharkhand', 'MN': 'Manipur', 'ML': 'Meghalaya',
      'MZ': 'Mizoram', 'NL': 'Nagaland', 'OR': 'Odisha',
      'SK': 'Sikkim', 'TR': 'Tripura', 'AN': 'Andaman and Nicobar Islands',
      'CH': 'Chandigarh', 'DN': 'Dadra and Nagar Haveli and Daman and Diu',
      'LD': 'Lakshadweep', 'PY': 'Puducherry',
    };

    String? deepFind(dynamic obj, List<String> searchKeys) {
      if (obj == null) return null;
      if (obj is Map) {
        for (final k in searchKeys) {
          final v = obj[k];
          if (v is String || v is num || v is bool) {
            final s = v.toString().trim();
            if (s.isNotEmpty) return s;
          }
        }
        for (final entry in obj.entries) {
          if (entry.value is Map || entry.value is List) {
            final found = deepFind(entry.value, searchKeys);
            if (found != null) return found;
          }
        }
      } else if (obj is List) {
        for (final item in obj) {
          final found = deepFind(item, searchKeys);
          if (found != null) return found;
        }
      }
      return null;
    }

    String? findState(String? input) {
      if (input == null) return null;
      var clean = input.trim().toUpperCase();
      final aliasMatch = stateAlias[clean];
      if (aliasMatch != null) clean = aliasMatch.toUpperCase();
      for (final s in _states) {
        if (s.toUpperCase() == clean) return s;
      }
      for (final s in _states) {
        if (clean.contains(s.toUpperCase())) return s;
      }
      return null;
    }

    String? searchAllForState(dynamic obj) {
      if (obj == null) return null;
      if (obj is String) {
        final match = findState(obj);
        if (match != null) return match;
      } else if (obj is Map) {
        for (final v in obj.values) {
          final m = searchAllForState(v);
          if (m != null) return m;
        }
      } else if (obj is List) {
        for (final v in obj) {
          final m = searchAllForState(v);
          if (m != null) return m;
        }
      }
      return null;
    }

    String? guessStateFromDistrict(String? dist) {
      if (dist == null) return null;
      final clean = dist.trim().toLowerCase();
      for (final entry in _districtsByState.entries) {
        for (final d in entry.value) {
          if (d.toLowerCase() == clean) return entry.key;
        }
      }
      return null;
    }

    setState(() {
      // 1. Name
      final nameStr = deepFind(data, ['full_name', 'name', 'name_on_card', 'Name', 'fullName']);
      debugPrint("DEBUG: _applyData parsed Name: '$nameStr'");
      if (nameStr != null && nameStr.isNotEmpty) {
        _fullName.text = nameStr;
      }
      
      // 2. DOB (Handle both flows)
      final dobValue = deepFind(data, ['date_of_birth', 'dob', 'birth_date', 'DOB', 'dateOfBirth']);
      debugPrint("DEBUG: _applyData parsed DOB Value: '$dobValue'");
      DateTime? parsedDob;
      if (dobValue != null) {
        try {
          parsedDob = DateTime.parse(dobValue);
        } catch (_) {
          final clean = dobValue.replaceAll(RegExp(r'[^0-9\-]'), '-').replaceAll('/', '-');
          final parts = clean.split('-').where((p) => p.isNotEmpty).toList();
          if (parts.length == 3) {
            try {
              int d = 0, m = 0, y = 0;
              if (parts[0].length == 4) { y = int.parse(parts[0]); m = int.parse(parts[1]); d = int.parse(parts[2]); }
              else if (parts[2].length == 4) { d = int.parse(parts[0]); m = int.parse(parts[1]); y = int.parse(parts[2]); }
              if (y > 0) parsedDob = DateTime(y, m, d);
            } catch (_) {}
          }
        }
      }
      
      // Prefer tempDob for DL, then parsedDob
      if (widget.session.tempDob != null) {
        _dob = widget.session.tempDob;
      } else if (parsedDob != null) {
        _dob = parsedDob;
      }

      if (_dob != null) {
        _dobController.text = _fmtDateDisplay(_dob!);
      }
      
      // 3. Gender
      final gStr = deepFind(data, ['gender', 'Gender', 'sex', 'Sex', 'Gnd'])?.toUpperCase();
      debugPrint("DEBUG: _applyData parsed Gender: '$gStr'");
      if (gStr != null && gStr.isNotEmpty) {
        if (gStr.startsWith('M')) _gender = 'M';
        else if (gStr.startsWith('F')) _gender = 'F';
        else if (gStr.startsWith('O')) _gender = 'O';
      }
      
      // 4. State & District
      final stateKeys = ['state', 'state_code', 'State', 'ST', 'region'];
      final distKeys = ['district', 'dist', 'District', 'DT', 'city', 'town', 'village'];
      final zipKeys = ['pincode', 'zip', 'zipcode', 'postal_code', 'pin'];
      
      var stateRaw = deepFind(data, stateKeys);
      var distRaw = deepFind(data, distKeys);
      var zipRaw = deepFind(data, zipKeys) ?? _profileZip;
      
      stateRaw ??= searchAllForState(data);
      _selectedState = findState(stateRaw);
      if (_selectedState == null) {
        _selectedState = guessStateFromDistrict(distRaw);
      }
      
      // Validate District
      if (_selectedState != null && distRaw != null) {
        final validDistricts = _districtsByState[_selectedState] ?? [];
        final m = validDistricts.firstWhere(
          (d) => d.toLowerCase() == distRaw!.toLowerCase(),
          orElse: () => "",
        );
        _selectedDistrict = m.isEmpty ? null : m;
      } else {
        _selectedDistrict = distRaw;
      }

      // 5. Address Harvesting
      final addressParts = <String>{};
      final skipKeys = {
        'state', 'name', 'full_name', 'gender', 'dob', 'date_of_birth', 
        'aadhaar_number', 'photo', 'kyc_session_uid', 'next', 'status', 'success'
      };
      
      void harvest(dynamic obj) {
        if (obj is Map) {
          for (final entry in obj.entries) {
            final key = entry.key.toString().toLowerCase();
            final val = entry.value;
            if (skipKeys.contains(key)) continue;
            if (val is String || val is num) {
              final s = val.toString().trim();
              if (s.isNotEmpty && s.length > 2) addressParts.add(s);
            } else if (val is Map || val is List) { harvest(val); }
          }
        } else if (obj is List) {
          for (final item in obj) harvest(item);
        }
      }

      harvest(data);
      final fallbackAddress = deepFind(data, ['address', 'full_address', 'address_raw']);
      if (fallbackAddress != null) addressParts.add(fallbackAddress);

      if (addressParts.isNotEmpty) {
        final sorted = addressParts.toList()
          ..removeWhere((p) => p == _selectedState || p == _selectedDistrict);
        // Reverse the address parts (Street first, etc.)
        final reversed = sorted.reversed.toList();
        var finalAddr = reversed.join(", ").trim();
        if (zipRaw != null && !finalAddr.contains(zipRaw)) finalAddr = "$finalAddr, $zipRaw";
        _address.text = finalAddr;
      }

      _hasAadhaarData = true;
      debugPrint("DEBUG: Auto-fill completed. hasAadhaarData=$_hasAadhaarData");
    });
  }

  String addressRaw(Map data) {
    if (data['address'] != null) return data['address'].toString();
    // Fallback if address is missing but segments exist
    final parts = <String>[];
    if (data['house'] != null) parts.add(data['house'].toString());
    if (data['street'] != null) parts.add(data['street'].toString());
    return parts.join(", ");
  }
  
  void _clearFormData() {
    _fullName.clear();
    _dobController.clear();
    _address.clear();
    if (!_isDL) {
      _dob = null;
    }
    _gender = null;
    _selectedState = null;
    _selectedDistrict = null;
  }

  Future<void> _checkMethod() async {
    if (_methodChecked) return;
    try {
      _methodChecked = true;
      final res = await widget.session.api.dio.get('/api/operators/profile/');
      final data = res.data as Map<String, dynamic>?;
      final method = data?['verification_method']?.toString();
      final dobStr = data?['date_of_birth']?.toString();
      final zip = data?['current_zip']?.toString();
      
      if (mounted) {
        setState(() {
          _isDL = method == 'DL';
          if (_isDL && dobStr != null) {
            try {
              _dob = DateTime.parse(dobStr);
              _dobController.text = _fmtDateDisplay(_dob!);
            } catch (_) {
              // Ignore parse error
            }
          }
          
          if (zip != null && zip.isNotEmpty) {
             _profileZip = zip;
             // If address is already filled (by auto-fill running earlier) but missing zip, append it
             if (_address.text.isNotEmpty && !_address.text.contains(zip)) {
                _address.text = "${_address.text}, $zip"; 
             }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isDL = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime(now.year - 10, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobController.text = _fmtDateDisplay(picked);
      });
    }
  }

  Future<void> _verify() async {
    final name = _fullName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = "Please enter your full name");
      return;
    }
    
    if (!_isDL && _dob == null) {
      setState(() => _error = "Please select Date of Birth");
      return;
    }

    if (_gender == null) {
      setState(() => _error = "Please select Gender");
      return;
    }

    if (_selectedState == null || _selectedState!.isEmpty) {
      setState(() => _error = "Please select State");
      return;
    }

    if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
      setState(() => _error = "Please select District");
      return;
    }

    final address = _address.text.trim();
    if (address.isEmpty) {
      setState(() => _error = "Please enter your full address");
      return;
    }
    
    // Check consent if Aadhaar data was used
    if (_hasAadhaarData && !_consentToUseAadhaarData) {
      setState(() => _error = "Please confirm the pre-filled details by checking the consent box");
      return;
    }

    final kycUid = widget.session.kycSessionUid;
    if (kycUid == null || kycUid.isEmpty) {
      setState(() => _error = "KYC session missing. Please restart verification.");
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      String endpoint = _isDL ? '/api/kyc/dl/verify-details/' : '/api/kyc/aadhaar/verify-details/';
      
      final requestData = <String, dynamic>{
        "kyc_session_uid": kycUid,
        "full_name": name,
        "gender": _gender,
        "state": _selectedState,
        "district": _selectedDistrict,
        "address": address,
      };
      
      if (!_isDL && _dob != null) {
        requestData["date_of_birth"] = _fmtDate(_dob!);
      }

      final res = await widget.session.api.dio.post(endpoint, data: requestData);
      final data = res.data;
      final match = data is Map ? data['match'] : false;

      if (match == true) {
        await widget.session.bootstrap();
      } else {
        final mismatches = data is Map ? data['mismatches'] : null;
        final message = data is Map ? data['message']?.toString() : null;
        
        String errorMsg = message ?? "Details do not match. Please verify and try again.";
        if (mismatches is Map) {
          final issues = <String>[];
          if (mismatches['name'] == true) issues.add("Name");
          if (mismatches['date_of_birth'] == true) issues.add("Date of Birth");
          if (mismatches['gender'] == true) issues.add("Gender");
          if (issues.isNotEmpty) {
            errorMsg = "${message}\nMismatch in: ${issues.join(", ")}";
          }
        }
        setState(() => _error = errorMsg);
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
      final msg = _prettyError(e);
      _showErrorPopup(msg, 
        title: (e is DioException && (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout)) ? "Connection Issue" : "Verification Error",
        icon: (e is DioException && (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout)) ? Icons.signal_wifi_off_rounded : Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_update);
    _fullName.dispose();
    _dobController.dispose();
    _address.dispose();
    super.dispose();
  }

  List<String> get _districts {
    if (_selectedState == null) {
      return [];
    }
    return _districtsByState[_selectedState] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    final bg = _isDark ? const Color(0xFF0C0E11) : const Color(0xFFF5F7FA);
    final textMain = _isDark ? Colors.white : const Color(0xFF1F2937);
    final textSub = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final cardColor = _isDark ? const Color(0xFF161A22) : Colors.white;
    final borderColor = _isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    final accentColor = const Color(0xFF6366F1); // Indigo

    InputDecoration inputDeco(String label, {String? hint, Widget? suffix}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: textSub.withOpacity(0.5)),
        labelStyle: TextStyle(color: textSub),
        floatingLabelStyle: TextStyle(color: accentColor),
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        suffixIcon: suffix,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // logic to reset or go back
        widget.session.setStage(OnboardingStage.chooseKycMethod);
      },
      child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/logo.png',
          height: 32,
        ),
        centerTitle: false,
        actions: [
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
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // No custom header needed

            // -- Scrollable Content --
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress Indicator

                    const SizedBox(height: 20),

                    // Title
                    Text(
                      "Verify Details",
                       style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      "Please confirm your details as they appear on your ID document:",
                      style: TextStyle(
                        fontSize: 16,
                        color: textSub,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // FULL NAME
                    Text("FULL NAME", style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _fullName,
                      readOnly: _fullName.text.isNotEmpty && _hasAadhaarData,
                      style: TextStyle(color: textMain),
                      decoration: inputDeco("Full Name"),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // DATE OF BIRTH
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("DATE OF BIRTH", style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              const SizedBox(height: 8),
                               InkWell(
                                  onTap: null, // Read-only
                                  borderRadius: BorderRadius.circular(12),
                                  child: TextField(
                                    controller: _dobController,
                                    readOnly: true,
                                    enabled: false,
                                    style: TextStyle(color: textMain),
                                    decoration: inputDeco(
                                      "Date of Birth", 
                                      suffix: Icon(Icons.calendar_today_outlined, size: 20, color: textSub)
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // GENDER
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("GENDER", style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _gender,
                                items: [
                                  DropdownMenuItem(value: 'M', child: Text("Male", style: TextStyle(color: textMain))),
                                  DropdownMenuItem(value: 'F', child: Text("Female", style: TextStyle(color: textMain))),
                                  DropdownMenuItem(value: 'O', child: Text("Other", style: TextStyle(color: textMain))),
                                ],
                                onChanged: (_gender != null && _hasAadhaarData) ? null : (v) => setState(() => _gender = v),
                                style: TextStyle(color: textMain, fontSize: 16),
                                decoration: inputDeco("Select Gender"),
                                dropdownColor: cardColor,
                                icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSub),
                                isExpanded: true, // Prevent overflow
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // STATE & DISTRICT
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("STATE *", style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedState,
                                items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 14, color: textMain), overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (_selectedState != null && _hasAadhaarData) ? null : (v) {
                                  setState(() {
                                    _selectedState = v;
                                    _selectedDistrict = null;
                                  });
                                },
                                style: TextStyle(color: textMain),
                                decoration: inputDeco("Select State"),
                                dropdownColor: cardColor,
                                icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSub),
                                isExpanded: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("DISTRICT *", style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedDistrict,
                                items: (_selectedState == null ? <String>[] : (_districtsByState[_selectedState] ?? []))
                                    .map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(fontSize: 14, color: textMain), overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (_selectedDistrict != null && _hasAadhaarData) ? null : (v) => setState(() => _selectedDistrict = v),
                                style: TextStyle(color: textMain),
                                decoration: inputDeco("Select District"),
                                dropdownColor: cardColor,
                                icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSub),
                                isExpanded: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text("FULL ADDRESS *", style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _address,
                      readOnly: _address.text.isNotEmpty && _hasAadhaarData,
                      maxLines: 4,
                      style: TextStyle(color: textMain, fontSize: 14, height: 1.5),
                      decoration: inputDeco("Address"),
                    ),
             const SizedBox(height: 24),
                    
                    // Consent Checkbox (at bottom)
                    if (_hasAadhaarData) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accentColor.withOpacity(0.2)),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _consentToUseAadhaarData = !_consentToUseAadhaarData;
                            });
                          },
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _consentToUseAadhaarData,
                                  onChanged: (value) {
                                    setState(() {
                                      _consentToUseAadhaarData = value ?? false;
                                    });
                                  },
                                  activeColor: accentColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "I confirm that the above details are correct and match my ${_isDL ? 'Driving License' : 'Aadhaar card'}",
                                  style: TextStyle(
                                    color: textMain,
                                    fontSize: 14,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],


                    // const SizedBox(height: 16), // Removed inline error padding

                    const SizedBox(height: 80), // Bottom padding for button
                  ],
                ),
              ),
            ),

            // -- Fixed Bottom Button --
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: bg,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_loading || (_hasAadhaarData && !_consentToUseAadhaarData)) ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accentColor.withOpacity(0.5),
                    disabledForegroundColor: Colors.white.withOpacity(0.7), // Ensure visible when disabled
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text("Verify & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20)
                        ],
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // Indian states list
  final List<String> _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand',
    'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
    'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman and Nicobar Islands', 'Chandigarh', 'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry'
  ];

  // Districts by state (simplified - you may want to use a more comprehensive list)
  final Map<String, List<String>> _districtsByState = {
    // --- States ---
    'Andhra Pradesh': [
      'Alluri Sitharama Raju', 'Anakapalli', 'Anantapur', 'Annamayya', 'Bapatla',
      'Chittoor', 'Dr. B.R. Ambedkar Konaseema', 'East Godavari', 'Eluru', 'Guntur',
      'Kakinada', 'Krishna', 'Kurnool', 'Nandyal', 'NTR',
      'Palnadu', 'Parvathipuram Manyam', 'Prakasam', 'Sri Potti Sriramulu Nellore', 'Sri Sathya Sai',
      'Srikakulam', 'Tirupati', 'Visakhapatnam', 'Vizianagaram', 'West Godavari',
      'YSR'
    ],
    'Arunachal Pradesh': [
      'Anjaw', 'Changlang', 'Dibang Valley', 'East Kameng', 'East Siang',
      'Kamle', 'Kra Daadi', 'Kurung Kumey', 'Lepa Rada', 'Lohit',
      'Longding', 'Lower Dibang Valley', 'Lower Siang', 'Lower Subansiri', 'Namsai',
      'Pakke Kessang', 'Papum Pare', 'Shi Yomi', 'Siang', 'Tawang',
      'Tirap', 'Upper Siang', 'Upper Subansiri', 'West Kameng', 'West Siang',
      'Itanagar Capital Complex'
    ],
    'Assam': [
      'Bajali', 'Baksa', 'Barpeta', 'Biswanath', 'Bongaigaon',
      'Cachar', 'Charaideo', 'Chirang', 'Darrang', 'Dhemaji',
      'Dhubri', 'Dibrugarh', 'Dima Hasao', 'Goalpara', 'Golaghat',
      'Hailakandi', 'Hojai', 'Jorhat', 'Kamrup', 'Kamrup Metropolitan',
      'Karbi Anglong', 'Karimganj', 'Kokrajhar', 'Lakhimpur', 'Majuli',
      'Morigaon', 'Nagaon', 'Nalbari', 'Sivasagar', 'Sonitpur',
      'South Salmara-Mankachar', 'Tamulpur', 'Tinsukia', 'Udalguri', 'West Karbi Anglong'
    ],
    'Bihar': [
      'Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai',
      'Bhagalpur', 'Bhojpur', 'Buxar', 'Darbhanga', 'East Champaran',
      'Gaya', 'Gopalganj', 'Jamui', 'Jehanabad', 'Kaimur',
      'Katihar', 'Khagaria', 'Kishanganj', 'Lakhisarai', 'Madhepura',
      'Madhubani', 'Munger', 'Muzaffarpur', 'Nalanda', 'Nawada',
      'Patna', 'Purnia', 'Rohtas', 'Saharsa', 'Samastipur',
      'Saran', 'Sheikhpura', 'Sheohar', 'Sitamarhi', 'Siwan',
      'Supaul', 'Vaishali', 'West Champaran'
    ],
    'Chhattisgarh': [
      'Balod', 'Baloda Bazar', 'Balrampur', 'Bastar', 'Bemetara',
      'Bijapur', 'Bilaspur', 'Dantewada', 'Dhamtari', 'Durg',
      'Gariaband', 'Gaurela-Pendra-Marwahi', 'Janjgir-Champa', 'Jashpur', 'Kabirdham',
      'Kanker', 'Khairagarh-Chhuikhadan-Gandai', 'Kondagaon', 'Korba', 'Koriya',
      'Mahasamund', 'Manendragarh-Chirimiri-Bharatpur', 'Mohla-Manpur-Ambagarh Chowki', 'Mungeli', 'Narayanpur',
      'Raigarh', 'Raipur', 'Rajnandgaon', 'Sakti', 'Sarangarh-Bilaigarh',
      'Sukma', 'Surajpur', 'Surguja'
    ],
    'Goa': [
      'North Goa', 'South Goa'
    ],
    'Gujarat': [
      'Ahmedabad', 'Amreli', 'Anand', 'Aravalli', 'Banaskantha',
      'Bharuch', 'Bhavnagar', 'Botad', 'Chhota Udaipur', 'Dahod',
      'Dang', 'Devbhoomi Dwarka', 'Gandhinagar', 'Gir Somnath', 'Jamnagar',
      'Junagadh', 'Kheda', 'Kutch', 'Mahisagar', 'Mehsana',
      'Morbi', 'Narmada', 'Navsari', 'Panchmahal', 'Patan',
      'Porbandar', 'Rajkot', 'Sabarkantha', 'Surat', 'Surendranagar',
      'Tapi', 'Vadodara', 'Valsad'
    ],
    'Haryana': [
      'Ambala', 'Bhiwani', 'Charkhi Dadri', 'Faridabad', 'Fatehabad',
      'Gurugram', 'Hisar', 'Jhajjar', 'Jind', 'Kaithal',
      'Karnal', 'Kurukshetra', 'Mahendragarh', 'Nuh', 'Palwal',
      'Panchkula', 'Panipat', 'Rewari', 'Rohtak', 'Sirsa',
      'Sonipat', 'Yamunanagar'
    ],
    'Himachal Pradesh': [
      'Bilaspur', 'Chamba', 'Hamirpur', 'Kangra', 'Kinnaur',
      'Kullu', 'Lahaul and Spiti', 'Mandi', 'Shimla', 'Sirmaur',
      'Solan', 'Una'
    ],
    'Jharkhand': [
      'Bokaro', 'Chatra', 'Deoghar', 'Dhanbad', 'Dumka',
      'East Singhbhum', 'Garhwa', 'Giridih', 'Godda', 'Gumla',
      'Hazaribagh', 'Jamtara', 'Khunti', 'Koderma', 'Latehar',
      'Lohardaga', 'Pakur', 'Palamu', 'Ramgarh', 'Ranchi',
      'Sahibganj', 'Seraikela Kharsawan', 'Simdega', 'West Singhbhum'
    ],
    'Karnataka': [
      'Bagalkot', 'Ballari', 'Belagavi', 'Bengaluru Rural', 'Bengaluru Urban',
      'Bidar', 'Chamarajanagar', 'Chikkaballapur', 'Chikkamagaluru', 'Chitradurga',
      'Dakshina Kannada', 'Davanagere', 'Dharwad', 'Gadag', 'Hassan',
      'Haveri', 'Kalaburagi', 'Kodagu', 'Kolar', 'Koppal',
      'Mandya', 'Mysuru', 'Raichur', 'Ramanagara', 'Shivamogga',
      'Tumakuru', 'Udupi', 'Uttara Kannada', 'Vijayanagara', 'Vijayapura',
      'Yadgir'
    ],
    'Kerala': [
      'Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasargod',
      'Kollam', 'Kottayam', 'Kozhikode', 'Malappuram', 'Palakkad',
      'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad'
    ],
    'Madhya Pradesh': [
      'Agar Malwa', 'Alirajpur', 'Anuppur', 'Ashoknagar', 'Balaghat',
      'Barwani', 'Betul', 'Bhind', 'Bhopal', 'Burhanpur',
      'Chhatarpur', 'Chhindwara', 'Damoh', 'Datia', 'Dewas',
      'Dhar', 'Dindori', 'Guna', 'Gwalior', 'Harda',
      'Hoshangabad', 'Indore', 'Jabalpur', 'Jhabua', 'Katni',
      'Khandwa', 'Khargone', 'Maihar', 'Mandla', 'Mandsaur',
      'Mauganj', 'Morena', 'Narsinghpur', 'Neemuch', 'Niwari',
      'Pandhurna', 'Panna', 'Raisen', 'Rajgarh', 'Ratlam',
      'Rewa', 'Sagar', 'Satna', 'Sehore', 'Seoni',
      'Shahdol', 'Shajapur', 'Sheopur', 'Shivpuri', 'Sidhi',
      'Singrauli', 'Tikamgarh', 'Ujjain', 'Umaria', 'Vidisha'
    ],
    'Maharashtra': [
      'Ahmednagar', 'Akola', 'Amravati', 'Aurangabad', 'Beed',
      'Bhandara', 'Buldhana', 'Chandrapur', 'Dhule', 'Gadchiroli',
      'Gondia', 'Hingoli', 'Jalgaon', 'Jalna', 'Kolhapur',
      'Latur', 'Mumbai City', 'Mumbai Suburban', 'Nagpur', 'Nanded',
      'Nandurbar', 'Nashik', 'Osmanabad', 'Palghar', 'Parbhani',
      'Pune', 'Raigad', 'Ratnagiri', 'Sangli', 'Satara',
      'Sindhudurg', 'Solapur', 'Thane', 'Wardha', 'Washim',
      'Yavatmal'
    ],
    'Manipur': [
      'Bishnupur', 'Chandel', 'Churachandpur', 'Imphal East', 'Imphal West',
      'Jiribam', 'Kakching', 'Kamjong', 'Kangpokpi', 'Noney',
      'Pherzawl', 'Senapati', 'Tamenglong', 'Tengnoupal', 'Thoubal',
      'Ukhrul'
    ],
    'Meghalaya': [
      'East Garo Hills', 'East Jaintia Hills', 'East Khasi Hills', 'Eastern West Khasi Hills',
      'North Garo Hills', 'Ri Bhoi', 'South Garo Hills', 'South West Garo Hills',
      'South West Khasi Hills', 'West Garo Hills', 'West Jaintia Hills', 'West Khasi Hills'
    ],
    'Mizoram': [
      'Aizawl', 'Champhai', 'Hnahthial', 'Khawzawl', 'Kolasib',
      'Lawngtlai', 'Lunglei', 'Mamit', 'Saiha', 'Saitual',
      'Serchhip'
    ],
    'Nagaland': [
      'Chumoukedima', 'Dimapur', 'Kiphire', 'Kohima', 'Longleng',
      'Mokokchung', 'Mon', 'Niuland', 'Noklak', 'Peren',
      'Phek', 'Shamator', 'Tseminyu', 'Tuensang', 'Wokha',
      'Zunheboto'
    ],
    'Odisha': [
      'Angul', 'Balangir', 'Balasore', 'Bargarh', 'Bhadrak',
      'Boudh', 'Cuttack', 'Deogarh', 'Dhenkanal', 'Gajapati',
      'Ganjam', 'Jagatsinghpur', 'Jajpur', 'Jharsuguda', 'Kalahandi',
      'Kandhamal', 'Kendrapara', 'Kendujhar', 'Khordha', 'Koraput',
      'Malkangiri', 'Mayurbhanj', 'Nabarangpur', 'Nayagarh', 'Nuapada',
      'Puri', 'Rayagada', 'Sambalpur', 'Subarnapur', 'Sundargarh'
    ],
    'Punjab': [
      'Amritsar', 'Barnala', 'Bathinda', 'Faridkot', 'Fatehgarh Sahib',
      'Fazilka', 'Ferozepur', 'Gurdaspur', 'Hoshiarpur', 'Jalandhar',
      'Kapurthala', 'Ludhiana', 'Malerkotla', 'Mansa', 'Moga',
      'Mohali', 'Muktsar', 'Pathankot', 'Patiala', 'Rupnagar',
      'Sangrur', 'Shaheed Bhagat Singh Nagar', 'Tarn Taran'
    ],
    'Rajasthan': [
      'Ajmer', 'Alwar', 'Anupgarh', 'Balotra', 'Banswara',
      'Baran', 'Barmer', 'Beawar', 'Bharatpur', 'Bhilwara',
      'Bikaner', 'Bundi', 'Chittorgarh', 'Churu', 'Dausa',
      'Deeg', 'Dholpur', 'Didwana-Kuchaman', 'Dudu', 'Dungarpur',
      'Gangapur City', 'Hanumangarh', 'Jaipur', 'Jaipur Rural', 'Jaisalmer',
      'Jalore', 'Jhalawar', 'Jhunjhunu', 'Jodhpur', 'Jodhpur Rural',
      'Karauli', 'Kekri', 'Khairthal-Tijara', 'Kota', 'Kotputli-Behror',
      'Nagaur', 'Neem Ka Thana', 'Pali', 'Phalodi', 'Pratapgarh',
      'Rajsamand', 'Salumbar', 'Sanchore', 'Sawai Madhopur', 'Shahpura',
      'Sikar', 'Sirohi', 'Sri Ganganagar', 'Tonk', 'Udaipur'
    ],
    'Sikkim': [
      'Gangtok', 'Gyalshing', 'Mangan', 'Namchi', 'Pakyong', 'Soreng'
    ],
    'Tamil Nadu': [
      'Ariyalur', 'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore',
      'Dharmapuri', 'Dindigul', 'Erode', 'Kallakurichi', 'Kancheepuram',
      'Karur', 'Krishnagiri', 'Madurai', 'Mayiladuthurai', 'Nagapattinam',
      'Namakkal', 'Nilgiris', 'Perambalur', 'Pudukkottai', 'Ramanathapuram',
      'Ranipet', 'Salem', 'Sivaganga', 'Tenkasi', 'Thanjavur',
      'Theni', 'Thoothukudi', 'Tiruchirappalli', 'Tirunelveli', 'Tirupathur',
      'Tiruppur', 'Tiruvallur', 'Tiruvannamalai', 'Tiruvarur', 'Vellore',
      'Viluppuram', 'Virudhunagar'
    ],
    'Telangana': [
      'Adilabad', 'Bhadradri Kothagudem', 'Hanumakonda', 'Hyderabad', 'Jagtial',
      'Jangaon', 'Jayashankar Bhupalpally', 'Jogulamba Gadwal', 'Kamareddy', 'Karimnagar',
      'Khammam', 'Komaram Bheem Asifabad', 'Mahabubabad', 'Mahabubnagar', 'Mancherial',
      'Medak', 'Medchal-Malkajgiri', 'Mulugu', 'Nagarkurnool', 'Nalgonda',
      'Narayanpet', 'Nirmal', 'Nizamabad', 'Peddapalli', 'Rajanna Sircilla',
      'Rangareddy', 'Sangareddy', 'Siddipet', 'Suryapet', 'Vikarabad',
      'Wanaparthy', 'Warangal', 'Yadadri Bhuvanagiri'
    ],
    'Tripura': [
      'Dhalai', 'Gomati', 'Khowai', 'North Tripura', 'Sepahijala',
      'South Tripura', 'Unakoti', 'West Tripura'
    ],
    'Uttar Pradesh': [
      'Agra', 'Aligarh', 'Ambedkar Nagar', 'Amethi', 'Amroha',
      'Auraiya', 'Ayodhya', 'Azamgarh', 'Baghpat', 'Bahraich',
      'Ballia', 'Balrampur', 'Banda', 'Barabanki', 'Bareilly',
      'Basti', 'Bhadohi', 'Bijnor', 'Budaun', 'Bulandshahr',
      'Chandauli', 'Chitrakoot', 'Deoria', 'Etah', 'Etawah',
      'Farrukhabad', 'Fatehpur', 'Firozabad', 'Gautam Buddha Nagar', 'Ghaziabad',
      'Ghazipur', 'Gonda', 'Gorakhpur', 'Hamirpur', 'Hapur',
      'Hardoi', 'Hathras', 'Jalaun', 'Jaunpur', 'Jhansi',
      'Kannauj', 'Kanpur Dehat', 'Kanpur Nagar', 'Kasganj', 'Kaushambi',
      'Kheri', 'Kushinagar', 'Lalitpur', 'Lucknow', 'Maharajganj',
      'Mahoba', 'Mainpuri', 'Mathura', 'Mau', 'Meerut',
      'Mirzapur', 'Moradabad', 'Muzaffarnagar', 'Pilibhit', 'Pratapgarh',
      'Prayagraj', 'Raebareli', 'Rampur', 'Saharanpur', 'Sambhal',
      'Sant Kabir Nagar', 'Shahjahanpur', 'Shamli', 'Shravasti', 'Siddharthnagar',
      'Sitapur', 'Sonbhadra', 'Sultanpur', 'Unnao', 'Varanasi'
    ],
    'Uttarakhand': [
      'Almora', 'Bageshwar', 'Chamoli', 'Champawat', 'Dehradun',
      'Haridwar', 'Nainital', 'Pauri Garhwal', 'Pithoragarh', 'Rudraprayag',
      'Tehri Garhwal', 'Udham Singh Nagar', 'Uttarkashi'
    ],
    'West Bengal': [
      'Alipurduar', 'Bankura', 'Birbhum', 'Cooch Behar', 'Dakshin Dinajpur',
      'Darjeeling', 'Hooghly', 'Howrah', 'Jalpaiguri', 'Jhargram',
      'Kalimpong', 'Kolkata', 'Malda', 'Murshidabad', 'Nadia',
      'North 24 Parganas', 'Paschim Bardhaman', 'Paschim Medinipur', 'Purba Bardhaman', 'Purba Medinipur',
      'Purulia', 'South 24 Parganas', 'Uttar Dinajpur'
    ],

    // --- Union Territories ---
    'Andaman and Nicobar Islands': [
      'Nicobar', 'North and Middle Andaman', 'South Andaman'
    ],
    'Chandigarh': [
      'Chandigarh'
    ],
    'Dadra and Nagar Haveli and Daman and Diu': [
      'Dadra and Nagar Haveli', 'Daman', 'Diu'
    ],
    'Delhi': [
      'Central Delhi', 'East Delhi', 'New Delhi', 'North Delhi', 'North East Delhi',
      'North West Delhi', 'Shahdara', 'South Delhi', 'South East Delhi', 'South West Delhi',
      'West Delhi'
    ],
    'Jammu and Kashmir': [
      'Anantnag', 'Bandipora', 'Baramulla', 'Budgam', 'Doda',
      'Ganderbal', 'Jammu', 'Kathua', 'Kishtwar', 'Kulgam',
      'Kupwara', 'Poonch', 'Pulwama', 'Rajouri', 'Ramban',
      'Reasi', 'Samba', 'Shopian', 'Srinagar', 'Udhampur'
    ],
    'Ladakh': [
      'Kargil', 'Leh'
    ],
    'Lakshadweep': [
      'Lakshadweep'
    ],
    'Puducherry': [
      'Karaikal', 'Mahe', 'Puducherry', 'Yanam'
    ],
  };

}
