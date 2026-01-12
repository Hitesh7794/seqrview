import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../app/session_controller.dart';

class OtpVerifyScreen extends StatefulWidget {
  final SessionController session;
  const OtpVerifyScreen({super.key, required this.session});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _resendLoading = false;
  String? _error;

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
    if (otp.length < 4) {
      setState(() => _error = "Please enter a valid OTP");
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
    final mobile = widget.session.mobile;
    if (mobile == null || mobile.isEmpty) {
      setState(() => _error = "Mobile missing. Please go back and enter mobile again.");
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
        throw Exception("Invalid server response: otp_session_uid missing");
      }
      widget.session.otpSessionUid = otpSessionUid;

      setState(() => _error = "OTP resent. Check SMS / dev console.");
    } catch (e) {
      setState(() => _error = _prettyError(e));
    } finally {
      setState(() => _resendLoading = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text("Enter the OTP sent to your mobile.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "OTP",
                hintText: "e.g. 123456",
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

            const SizedBox(height: 8),

            Row(
              children: [
                TextButton(
                  onPressed: _resendLoading ? null : _resend,
                  child: _resendLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Resend OTP"),
                ),
              ],
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
