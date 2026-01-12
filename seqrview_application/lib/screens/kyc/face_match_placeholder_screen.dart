import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/session_controller.dart';

class FaceMatchPlaceholderScreen extends StatefulWidget {
  final SessionController session;
  const FaceMatchPlaceholderScreen({super.key, required this.session});

  @override
  State<FaceMatchPlaceholderScreen> createState() => _FaceMatchPlaceholderScreenState();
}

class _FaceMatchPlaceholderScreenState extends State<FaceMatchPlaceholderScreen> {
  final _picker = ImagePicker();
  bool _loading = false;
  String? _error;

  Future<void> _captureLivenessThenMatch() async {
    final access = await widget.session.storage.getAccess();
    if (access == null || access.isEmpty) {
      setState(() => _error = "Session expired. Please re-login and retry.");
      return;
    }

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

      // 1) Liveness check with the selfie
      final liveResp = await widget.session.api.dio.post(
        '/api/kyc/face/liveness/',
        data: FormData.fromMap({
          "kyc_session_uid": kycUid,
          "selfie": await MultipartFile.fromFile(shot.path, filename: "selfie.jpg"),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );

      final liveData = liveResp.data;
      final isLive = liveData is Map && (liveData['live'] == true);
      if (!isLive) {
        setState(() => _error = "Liveness failed. Please try again.");
        return;
      }

      // 2) Face match with the SAME selfie file
      await widget.session.api.dio.post(
        '/api/kyc/face/match/',
        data: FormData.fromMap({
          "kyc_session_uid": kycUid,
          "selfie": await MultipartFile.fromFile(shot.path, filename: "selfie.jpg"),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );

      // Success: refresh state; router will redirect to home or failed screen
      await widget.session.bootstrap();
    } catch (e) {
      String msg = "Something went wrong";
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        } else {
          msg = "Network/API error (${e.response?.statusCode ?? 'no status'})";
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
    return Scaffold(
      appBar: AppBar(title: const Text("Face Match")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Take one selfie. We'll check liveness first, then match with your Aadhaar photo.",
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
                onPressed: _loading ? null : _captureLivenessThenMatch,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Capture Selfie"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
