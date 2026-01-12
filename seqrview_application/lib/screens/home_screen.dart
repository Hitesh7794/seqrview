import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../app/session_controller.dart';

class HomeScreen extends StatefulWidget {
  final SessionController session;
  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _userData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Fetch profile and user data in parallel
      final profileRes = await widget.session.api.dio.get('/api/operators/profile/');
      final userRes = await widget.session.api.dio.get('/api/identity/me/');

      if (mounted) {
        setState(() {
          _profileData = profileRes.data as Map<String, dynamic>?;
          _userData = userRes.data as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is DioException
              ? (e.response?.data?['detail']?.toString() ?? "Failed to load data")
              : "Failed to load data";
          _loading = false;
        });
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return dateStr;
    }
  }

  String _getKycMethodDisplay(String? method) {
    switch (method) {
      case 'AADHAAR':
        return 'Aadhaar';
      case 'DL':
        return 'Driving License';
      default:
        return method ?? 'N/A';
    }
  }

  String _getKycStatusDisplay(String? status) {
    switch (status) {
      case 'VERIFIED':
        return 'Verified';
      case 'FACE_PENDING':
        return 'Face Match Pending';
      case 'OTP_VERIFIED':
        return 'Details Verified';
      case 'FAILED':
        return 'Failed';
      default:
        return status ?? 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          IconButton(
            onPressed: () => widget.session.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Welcome, ${_userData?['full_name'] ?? _userData?['first_name'] ?? 'Operator'}",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_userData?['mobile_primary'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    "Mobile: ${_userData?['mobile_primary']}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // KYC Status Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "KYC Status",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  "Status",
                                  _getKycStatusDisplay(_profileData?['kyc_status']),
                                  _profileData?['kyc_status'] == 'VERIFIED'
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  "Method",
                                  _getKycMethodDisplay(_profileData?['verification_method']),
                                  null,
                                ),
                                if (_profileData?['kyc_verified_at'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    "Verified On",
                                    _formatDate(_profileData?['kyc_verified_at']),
                                    null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Profile Status Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Profile Information",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_profileData?['date_of_birth'] != null)
                                  _buildInfoRow(
                                    "Date of Birth",
                                    _formatDate(_profileData?['date_of_birth']),
                                    null,
                                  ),
                                if (_profileData?['gender'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    "Gender",
                                    _profileData?['gender'] == 'M'
                                        ? 'Male'
                                        : _profileData?['gender'] == 'F'
                                            ? 'Female'
                                            : 'Other',
                                    null,
                                  ),
                                ],
                                if (_profileData?['current_state'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    "State",
                                    _profileData?['current_state'],
                                    null,
                                  ),
                                ],
                                if (_profileData?['current_district'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    "District",
                                    _profileData?['current_district'],
                                    null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color? valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? Colors.black87,
              fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

