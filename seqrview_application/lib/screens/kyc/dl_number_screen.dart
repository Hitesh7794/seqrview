import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

  bool _loading = false;
  String? _error;

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
    return "$y-$m-$day";
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

  Future<void> _start() async {
    final licenseNumber = _licenseNumber.text.trim().toUpperCase();
    if (licenseNumber.isEmpty) {
      setState(() => _error = "Please enter your driving license number");
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
          "dob": _fmtDate(_dob!),
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

      // Navigate to verify details screen
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dobText = _dob == null ? "Select Date of Birth" : _fmtDate(_dob!);
    final disabled = _loading;

    return Scaffold(
      appBar: AppBar(title: const Text("Driving License Verification")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Enter your driving license number and date of birth to verify your identity.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _licenseNumber,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: "License Number",
                hintText: "e.g. TS02620190003657",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: disabled ? null : _pickDob,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: Text(dobText),
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
                onPressed: disabled ? null : _start,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Verify License"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

