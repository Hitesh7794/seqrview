import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../app/session_controller.dart';
import '../core/config.dart';

class ProfileScreen extends StatefulWidget {
  final SessionController session;
  const ProfileScreen({super.key, required this.session});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _userData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  String _getPhotoUrl() {
    // Construct photo URL if available
    final photo = _userData?['photo'];
    if (photo == null || photo.toString().isEmpty) return '';
    final photoStr = photo.toString();
    if (photoStr.startsWith('http://') || photoStr.startsWith('https://')) {
      return photoStr;
    }
    // Handle relative URLs - Django serves media at /media/
    // Photo path from DB is like "user_photos/selfie_z1Qpe20.jpg"
    // We need to prepend /media/ to it
    if (photoStr.startsWith('/')) {
      // Already has leading slash, just prepend base URL
      return '$apiBaseUrl$photoStr';
    }
    // No leading slash, add /media/ prefix
    return '$apiBaseUrl/media/$photoStr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Personal Info'),
            Tab(text: 'KYC Details'),
            Tab(text: 'Address'),
          ],
        ),
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
                  child: Column(
                    children: [
                      // Profile Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Column(
                          children: [
                            // Profile Photo
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _getPhotoUrl().isNotEmpty
                                  ? NetworkImage(_getPhotoUrl())
                                  : null,
                              child: _getPhotoUrl().isEmpty
                                  ? Icon(Icons.person, size: 50, color: Colors.grey[600])
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _userData?['full_name'] ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_userData?['mobile_primary'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _userData?['mobile_primary'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Tab Content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPersonalInfoTab(),
                            _buildKycDetailsTab(),
                            _buildAddressTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPersonalInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            "Personal Information",
            [
              _buildInfoRow("Full Name", _userData?['full_name'] ?? 'N/A'),
              _buildInfoRow("First Name", _userData?['first_name'] ?? 'N/A'),
              _buildInfoRow("Last Name", _userData?['last_name'] ?? 'N/A'),
              _buildInfoRow("Email", _userData?['email'] ?? 'N/A'),
              _buildInfoRow("Mobile", _userData?['mobile_primary'] ?? 'N/A'),
              _buildInfoRow("Username", _userData?['username'] ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            "Additional Details",
            [
              _buildInfoRow("Date of Birth", _formatDate(_profileData?['date_of_birth'])),
              _buildInfoRow(
                "Gender",
                _profileData?['gender'] == 'M'
                    ? 'Male'
                    : _profileData?['gender'] == 'F'
                        ? 'Female'
                        : _profileData?['gender'] == 'O'
                            ? 'Other'
                            : _profileData?['gender'] ?? 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKycDetailsTab() {
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
        case 'OTP_SENT':
          return 'OTP Sent';
        case 'NOT_STARTED':
          return 'Not Started';
        case 'FAILED':
          return 'Failed';
        default:
          return status ?? 'N/A';
      }
    }

    String _getProfileStatusDisplay(String? status) {
      switch (status) {
        case 'VERIFIED':
          return 'Verified';
        case 'KYC_IN_PROGRESS':
          return 'KYC In Progress';
        case 'PROFILE_FILLED':
          return 'Profile Filled';
        case 'DRAFT':
          return 'Draft';
        case 'REJECTED':
          return 'Rejected';
        default:
          return status ?? 'N/A';
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            "KYC Status",
            [
              _buildInfoRow(
                "Profile Status",
                _getProfileStatusDisplay(_profileData?['profile_status']),
                _profileData?['profile_status'] == 'VERIFIED' ? Colors.green : null,
              ),
              _buildInfoRow(
                "KYC Status",
                _getKycStatusDisplay(_profileData?['kyc_status']),
                _profileData?['kyc_status'] == 'VERIFIED' ? Colors.green : null,
              ),
              _buildInfoRow(
                "Verification Method",
                _getKycMethodDisplay(_profileData?['verification_method']),
              ),
              if (_profileData?['kyc_verified_at'] != null)
                _buildInfoRow("Verified On", _formatDate(_profileData?['kyc_verified_at'])),
              if (_profileData?['kyc_fail_reason'] != null)
                _buildInfoRow(
                  "Failure Reason",
                  _profileData?['kyc_fail_reason'],
                  Colors.red,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            "Current Address",
            [
              _buildInfoRow("Address", _profileData?['current_address'] ?? 'N/A'),
              _buildInfoRow("State", _profileData?['current_state'] ?? 'N/A'),
              _buildInfoRow("District", _profileData?['current_district'] ?? 'N/A'),
              _buildInfoRow("ZIP Code", _profileData?['current_zip'] ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
          if (_profileData?['permanent_address'] != null ||
              _profileData?['permanent_state'] != null)
            _buildInfoCard(
              "Permanent Address",
              [
                _buildInfoRow("Address", _profileData?['permanent_address'] ?? 'N/A'),
                _buildInfoRow("State", _profileData?['permanent_state'] ?? 'N/A'),
                _buildInfoRow("District", _profileData?['permanent_district'] ?? 'N/A'),
                _buildInfoRow("ZIP Code", _profileData?['permanent_zip'] ?? 'N/A'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
      ),
    );
  }
}

