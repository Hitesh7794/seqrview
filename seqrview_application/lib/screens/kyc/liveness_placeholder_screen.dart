import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/session_controller.dart';

class LivenessPlaceholderScreen extends StatefulWidget {
  final SessionController session;
  const LivenessPlaceholderScreen({super.key, required this.session});

  @override
  State<LivenessPlaceholderScreen> createState() => _LivenessPlaceholderScreenState();
}

class _LivenessPlaceholderScreenState extends State<LivenessPlaceholderScreen> {
  final _picker = ImagePicker();
  bool _loading = false;
  String? _error;
  int? _cooldown; // if backend returns retry_after_seconds

  Future<void> _captureAndSubmit() async {
    final kycUid = widget.session.kycSessionUid;
    if (kycUid == null || kycUid.isEmpty) {
      setState(() => _error = "KYC session missing. Please restart Aadhaar verification.");
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final XFile? shot = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
      if (shot == null) {
        setState(() => _error = "Capture cancelled.");
        return;
      }

      final form = FormData.fromMap({
        "kyc_session_uid": kycUid,
        "selfie": await MultipartFile.fromFile(shot.path, filename: "selfie.jpg"),
      });

      final res = await widget.session.api.dio.post(
        '/api/kyc/face/liveness/',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );

      // If backend returns retry_after_seconds on success, store it
      if (res.data is Map && res.data['retry_after_seconds'] != null) {
        final v = res.data['retry_after_seconds'];
        _cooldown = v is int ? v : int.tryParse(v.toString());
      }

      await widget.session.bootstrap(); // will redirect to face match
    } catch (e) {
      String msg = "Something went wrong";
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        } else {
          msg = "Network/API error (${e.response?.statusCode ?? 'no status'})";
        }
        if (data is Map && data['retry_after_seconds'] != null) {
          final v = data['retry_after_seconds'];
          _cooldown = v is int ? v : int.tryParse(v.toString());
        }
      } else {
        msg = e.toString();
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme
    final isDark = widget.session.isDark;
    final bg = isDark ? const Color(0xFF0C0E11) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text("Face Liveness")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Take a quick selfie so we can check liveness.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
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
                onPressed: _loading ? null : _captureAndSubmit,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_cooldown != null ? "Retry in ${_cooldown}s" : "Capture Selfie"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
