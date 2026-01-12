import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app/session_controller.dart';

class AadhaarOtpScreen extends StatefulWidget {
  final SessionController session;
  const AadhaarOtpScreen({super.key, required this.session});

  @override
  State<AadhaarOtpScreen> createState() => _AadhaarOtpScreenState();
}

class _AadhaarOtpScreenState extends State<AadhaarOtpScreen> {
  final _otp = TextEditingController();

  bool _loading = false;
  bool _resendLoading = false;
  String? _error;

  int _attempts = 0;
  static const int _maxAttempts = 5;

  // cooldown for resend / rate-limit
  int _cooldown = 0; // seconds left
  DateTime? _cooldownEndsAt;
  Timer? _ticker;

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

    // persist cooldown
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

    final otp = _otp.text.trim();
    if (otp.length < 4) {
      setState(() => _error = "Please enter valid OTP");
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await widget.session.api.dio.post(
        '/api/kyc/aadhaar/submit-otp/',
        data: {"kyc_session_uid": kycUid, "otp": otp},
      );

      // success => reset attempts
      _attempts = 0;

      await widget.session.bootstrap(); // should redirect to liveness placeholder
    } catch (e) {
      setState(() {
        _attempts += 1;
        _error = "${_prettyError(e)}  (Attempt $_attempts/$_maxAttempts)";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Resend OTP: we DO NOT store Aadhaar number in app.
  /// Backend should do idempotency: if OTP already sent & not expired, return same session.
  ///
  /// For resend, we call a dedicated endpoint ideally:
  ///   POST /api/kyc/aadhaar/resend/
  ///
  /// But if you don't have it, you can still call /aadhaar/start/ ONLY if backend supports "already_sent" flow.
  ///
  /// IMPORTANT: If your backend /aadhaar/start/ requires id_number, then you MUST implement resend endpoint
  /// that uses the existing KycSession's dedupe_hash/client_id.
  Future<void> _resend() async {
    if (_cooldown > 0) return;

    setState(() {
      _error = null;
      _resendLoading = true;
    });

    try {
      // ✅ RECOMMENDED ENDPOINT:
      // POST /api/kyc/aadhaar/resend/  -> uses existing session server-side.
      final res = await widget.session.api.dio.post('/api/kyc/aadhaar/resend/', data: {});

      final data = res.data;
      if (data is Map && data['kyc_session_uid'] != null) {
        final uid = data['kyc_session_uid'].toString();
        widget.session.kycSessionUid = uid;
        await widget.session.storage.saveKycSessionUid(uid);
      }

      // start cooldown if provided
      if (data is Map && data['retry_after_seconds'] != null) {
        final v = data['retry_after_seconds'];
        final wait = v is int ? v : int.tryParse(v.toString()) ?? 0;
        if (wait > 0) await _startCooldown(wait);
      } else {
        // default cooldown to avoid spam
        await _startCooldown(60);
      }

      // reset attempts on resend
      setState(() {
        _attempts = 0;
        _error = "OTP resent. Please check your mobile.";
      });
    } catch (e) {
      // 429 handling
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
      if (mounted) setState(() => _resendLoading = false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verifyDisabled = _loading;
    final resendDisabled = _resendLoading || _cooldown > 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Enter Aadhaar OTP")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Enter OTP sent to your Aadhaar-linked mobile.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "OTP", border: OutlineInputBorder()),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                TextButton(
                  onPressed: resendDisabled ? null : _resend,
                  child: _resendLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_cooldown > 0 ? "Resend in ${_cooldown}s" : "Resend OTP"),
                ),
                const Spacer(),
                Text("Attempts: $_attempts/$_maxAttempts"),
              ],
            ),

            if (_cooldown > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.orange.withOpacity(0.12),
                ),
                child: Text(
                  "Please wait ${_cooldown}s before resending OTP.",
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
                onPressed: verifyDisabled ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Verify Aadhaar OTP"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
