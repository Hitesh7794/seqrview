import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/session_controller.dart';
import '../../app/router.dart';

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
    if (mobile.length < 10) {
      setState(() {
        _loading = false;
        _error = "Please enter a valid mobile number";
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

      if (!mounted) return;
      context.go(otpPath);
    } catch (e) {
      setState(() => _error = _prettyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Operator Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text("Enter your mobile number. We'll send an OTP.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Mobile Number",
                hintText: "e.g. 9999999999",
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
                onPressed: _loading ? null : _sendOtp,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Send OTP"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
