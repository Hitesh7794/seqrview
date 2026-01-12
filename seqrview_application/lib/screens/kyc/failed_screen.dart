import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app/session_controller.dart';
import '../../app/onboarding_stage.dart';

class FailedScreen extends StatefulWidget {
  final SessionController session;
  const FailedScreen({super.key, required this.session});

  @override
  State<FailedScreen> createState() => _FailedScreenState();
}

class _FailedScreenState extends State<FailedScreen> {
  bool _loading = true;
  String? _kycFailReason;
  bool _canRetryFaceMatch = false;

  @override
  void initState() {
    super.initState();
    _loadFailureInfo();
  }

  Future<void> _loadFailureInfo() async {
    try {
      final res = await widget.session.api.dio.get('/api/operators/profile/');
      final data = res.data as Map<String, dynamic>;
      final failReason = (data['kyc_fail_reason'] ?? '').toString();
      final kycStatus = (data['kyc_status'] ?? '').toString();
      
      setState(() {
        _kycFailReason = failReason;
        // Only allow face match retry if failure was at face match stage
        // (not at OTP or details verification stage)
        _canRetryFaceMatch = failReason.toLowerCase().contains('face') || 
                            kycStatus == 'FACE_PENDING';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _canRetryFaceMatch = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("KYC Failed")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const Text("Your KYC failed. You can restart Aadhaar verification.", style: TextStyle(fontSize: 16)),
                  if (_kycFailReason != null && _kycFailReason!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text("Reason: $_kycFailReason", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                  const SizedBox(height: 16),
                  // Only show "Retry Face Match" if failure was at face match stage
                  if (_canRetryFaceMatch) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.session.setStage(OnboardingStage.faceMatch);
                        },
                        child: const Text("Retry Face Match"),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () async {
                        await widget.session.resetKyc();
                      },
                      child: const Text("Restart KYC"),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
