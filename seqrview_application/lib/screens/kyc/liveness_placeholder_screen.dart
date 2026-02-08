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

  String _prettyError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return "The service is taking too long to respond. Please check your internet or try again later.";
      }
      if (e.type == DioExceptionType.connectionError) {
        return "Cannot connect to our servers. Please check your internet connection.";
      }

      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      if (data is Map && data['message'] != null) return data['message'].toString();
      if (data is Map && data['reason'] != null) return data['reason'].toString();

      return "Network/API error (${e.response?.statusCode ?? 'no status'})";
    }
    return "An unexpected error occurred. Please try again.";
  }

  void _showErrorPopup(String message, {String title = "Connection Issue", IconData icon = Icons.signal_wifi_off_rounded}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: widget.session.isDark ? const Color(0xFF161A22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: Colors.orangeAccent, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: widget.session.isDark ? Colors.white : const Color(0xFF1F2937),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: widget.session.isDark ? const Color(0xFF8B949E) : const Color(0xFF4B5563),
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
      final msg = _prettyError(e);
      setState(() => _error = msg);
      if (e is DioException && (
          e.type == DioExceptionType.connectionError || 
          e.type == DioExceptionType.connectionTimeout)) {
        _showErrorPopup(msg);
      } else if (e is DioException && e.response?.data is Map && e.response?.data['retry_after_seconds'] != null) {
        final v = e.response?.data['retry_after_seconds'];
        _cooldown = v is int ? v : int.tryParse(v.toString());
      }
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
