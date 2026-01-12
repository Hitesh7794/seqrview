import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app/session_controller.dart';

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

  // cooldown for rate-limit
  int _cooldown = 0; // seconds left
  DateTime? _cooldownEndsAt;
  Timer? _ticker;

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  String _prettyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      if (data is Map && data['reason'] != null) return data['reason'].toString();
      return "Network/API error (${e.response?.statusCode ?? 'no status'})";
    }
    return e.toString();
  }

  @override
  void initState() {
    super.initState();
    _restoreCooldown();
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

    // ✅ persist cooldown
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

      // ✅ If backend returns retry_after_seconds (either already_sent or rate-limited style response)
      if (data is Map && data['retry_after_seconds'] != null) {
        final v = data['retry_after_seconds'];
        final wait = v is int ? v : int.tryParse(v.toString()) ?? 0;
        if (wait > 0) {
          await _startCooldown(wait);
        }
      }

      await widget.session.bootstrap(); // router redirects to Aadhaar OTP screen
    } catch (e) {
      // ✅ Handle 429 nicely
      if (e is DioException && e.response?.statusCode == 429) {
        int wait = 60; // default
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
    final disabled = _loading || _cooldown > 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Aadhaar Verification")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Enter Aadhaar number to receive OTP.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            TextField(
              controller: _aadhaar,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Aadhaar Number",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            if (_cooldown > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.orange.withOpacity(0.12),
                ),
                child: Text(
                  "Please wait ${_cooldown}s before requesting OTP again.",
                  style: const TextStyle(color: Colors.orange),
                ),
              ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.red.withOpacity(0.08),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ],

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: disabled ? null : _start,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_cooldown > 0 ? "Retry in ${_cooldown}s" : "Send Aadhaar OTP"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
