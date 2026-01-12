import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app/session_controller.dart';

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
  final _address = TextEditingController();
  DateTime? _dob;
  String _gender = "M";
  String? _selectedState;
  String? _selectedDistrict;

  bool _loading = false;
  bool _isDL = false;
  bool _methodChecked = false; // Prevent multiple checks
  String? _error;

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
  Map<String, List<String>> _districtsByState = {
    'Rajasthan': ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer', 'Bikaner', 'Alwar', 'Bharatpur'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Jamnagar', 'Gandhinagar'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad', 'Solapur', 'Thane'],
    'Karnataka': ['Bangalore', 'Mysore', 'Hubli', 'Mangalore', 'Belgaum', 'Gulbarga'],
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem', 'Tirunelveli'],
    'Uttar Pradesh': ['Lucknow', 'Kanpur', 'Agra', 'Varanasi', 'Allahabad', 'Meerut', 'Ghaziabad'],
    'West Bengal': ['Kolkata', 'Howrah', 'Durgapur', 'Asansol', 'Siliguri'],
    'Delhi': ['Central Delhi', 'North Delhi', 'South Delhi', 'East Delhi', 'West Delhi', 'New Delhi'],
    // Add more states and districts as needed
  };

  List<String> get _districts {
    if (_selectedState == null) return [];
    return _districtsByState[_selectedState!] ?? [];
  }

  String _prettyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      if (data is Map && data['message'] != null) return data['message'].toString();
      return "Network/API error (${e.response?.statusCode ?? 'no status'})";
    }
    return e.toString();
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
  }

  @override
  void initState() {
    super.initState();
    // User will manually fill in details - no auto-fill
    _checkMethod();
  }

  Future<void> _checkMethod() async {
    // Prevent multiple simultaneous checks
    if (_methodChecked) return;
    
    try {
      _methodChecked = true;
      final profileRes = await widget.session.api.dio.get('/api/operators/profile/');
      final profileData = profileRes.data as Map<String, dynamic>?;
      final method = profileData?['verification_method']?.toString();
      if (mounted) {
        setState(() {
          _isDL = method == 'DL';
        });
      }
    } catch (e) {
      // If profile fetch fails (401, network error, etc.), default to Aadhaar (show DOB)
      // Don't retry - just use default
      if (mounted) {
        setState(() {
          _isDL = false; // Default to Aadhaar
        });
      }
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
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _verify() async {
    final name = _fullName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = "Please enter your full name");
      return;
    }
    
    // DOB only required for Aadhaar, not for DL (already collected at DL input screen)
    if (!_isDL && _dob == null) {
      setState(() => _error = "Please select Date of Birth");
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
      // Determine endpoint based on verification method
      String endpoint = _isDL ? '/api/kyc/dl/verify-details/' : '/api/kyc/aadhaar/verify-details/';
      
      // Build request data
      final requestData = <String, dynamic>{
        "kyc_session_uid": kycUid,
        "full_name": name,
        "gender": _gender,
        "state": _selectedState,
        "district": _selectedDistrict,
        "address": address,
      };
      
      // Only include DOB for Aadhaar
      if (!_isDL && _dob != null) {
        requestData["date_of_birth"] = _fmtDate(_dob!);
      }

      final res = await widget.session.api.dio.post(
        endpoint,
        data: requestData,
      );

      final data = res.data;
      final match = data is Map ? data['match'] : false;
      final next = data is Map ? data['next']?.toString() : null;

      if (match == true) {
        // Details verified successfully - proceed to face match (which combines liveness + match)
        await widget.session.bootstrap();
      } else {
        // Mismatch - show error and allow retry
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
      setState(() => _error = _prettyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dobText = _dob == null ? "Select DOB" : _fmtDate(_dob!);

    return Scaffold(
      appBar: AppBar(title: const Text("Verify Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please enter your details as they appear on your ID document:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 12),
            TextField(
              controller: _fullName,
              decoration: const InputDecoration(
                labelText: "Full Name",
                hintText: "Enter your full name as on your ID",
                border: OutlineInputBorder(),
              ),
            ),
            // Only show DOB picker for Aadhaar, not for DL (DOB already collected at DL input screen)
            if (!_isDL) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _pickDob,
                      child: Text(dobText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _gender,
                    items: const [
                      DropdownMenuItem(value: "M", child: Text("Male")),
                      DropdownMenuItem(value: "F", child: Text("Female")),
                      DropdownMenuItem(value: "O", child: Text("Other")),
                    ],
                    onChanged: _loading ? null : (v) => setState(() => _gender = v ?? "M"),
                  ),
                ],
              ),
            ] else ...[
              // For DL, only show gender dropdown
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  labelText: "Gender",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "M", child: Text("Male")),
                  DropdownMenuItem(value: "F", child: Text("Female")),
                  DropdownMenuItem(value: "O", child: Text("Other")),
                ],
                onChanged: _loading ? null : (v) => setState(() => _gender = v ?? "M"),
              ),
            ],
            // State and District dropdowns (for both Aadhaar and DL)
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedState,
              decoration: const InputDecoration(
                labelText: "State *",
                border: OutlineInputBorder(),
              ),
              items: _states.map((state) => DropdownMenuItem(
                value: state,
                child: Text(state),
              )).toList(),
              onChanged: _loading ? null : (v) {
                setState(() {
                  _selectedState = v;
                  _selectedDistrict = null; // Reset district when state changes
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedDistrict,
              decoration: const InputDecoration(
                labelText: "District *",
                border: OutlineInputBorder(),
                hintText: "Select state first",
              ),
              items: _districts.map((district) => DropdownMenuItem(
                value: district,
                child: Text(district),
              )).toList(),
              onChanged: _loading || _selectedState == null ? null : (v) {
                setState(() => _selectedDistrict = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Full Address *",
                hintText: "Enter your complete address",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.red.withOpacity(0.08),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Verify & Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

