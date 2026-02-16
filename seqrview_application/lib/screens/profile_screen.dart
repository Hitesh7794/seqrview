import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../app/session_controller.dart';
import '../core/config.dart';
import '../../widgets/global_support_button.dart';

class ProfileScreen extends StatefulWidget {
  final SessionController session;
  final bool isActive;

  const ProfileScreen({
    super.key, 
    required this.session,
    this.isActive = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _userData;
  bool _loading = true;
  String? _error;

  // Theme State
  bool get _isDark => widget.session.isDark;

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_update);
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh when tab becomes active
    if (widget.isActive && !oldWidget.isActive) {
      _loadData();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_update);
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
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
           widget.session.logout();
           return; 
        }

        String msg = "Failed to load data. Please try again.";
        if (e is DioException) {
           if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
             msg = "Please check your internet connection.";
           } else if (e.response?.statusCode == 500) {
             msg = "Server is currently unavailable.";
           }
        }

        setState(() {
          _error = msg;
          _loading = false;
        });
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateStr).toLocal(); // Ensure local time
      final d = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      final y = date.year;
      final h = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');
      final s = date.second.toString().padLeft(2, '0');
      return "$d/$m/$y $h:$min:$s";
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
    if (photoStr.startsWith('/')) {
      return '$apiBaseUrl$photoStr';
    }
    return '$apiBaseUrl/media/$photoStr';
  }
  
  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: _isDark ? const Color(0xFF1E2433) : Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Grabber Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Theme Toggle
              ListTile(
                leading: Icon(
                  _isDark ? Icons.light_mode : Icons.dark_mode, 
                  color: _isDark ? Colors.amber : Colors.indigo
                ),
                title: Text(
                  _isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
                  style: TextStyle(
                    color: _isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                 onTap: () {
                  Navigator.pop(context);
                  widget.session.toggleTheme();
                },
              ),
              const Divider(),
              
              // Logout
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.red, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.session.logout();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF111827) : Colors.grey[50],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Unavailable",
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                            color: _isDark ? Colors.white : Colors.blueGrey,
                          )
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!, 
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500])
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // -- Unified Gradient Header --
                    // -- Seamless Header --
                    Container(
                      width: double.infinity,
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            // 1. Top Bar (Title + Settings)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Image.asset(
                                    'assets/images/logo.png',
                                    height: 32,
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildHeaderIcon(
                                        child: GlobalSupportButton(isDark: _isDark),
                                        isDark: _isDark,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildHeaderIcon(
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                          onPressed: _showSettingsModal,
                                          icon: Icon(Icons.settings, color: _isDark ? Colors.white : Colors.black87, size: 22),
                                          tooltip: 'Settings',
                                        ),
                                        isDark: _isDark,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                              
                              const SizedBox(height: 10),

                              // 2. Avatar with Green Dot
                              Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _isDark ? Colors.white : Colors.grey[300]!, 
                                        width: 3
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: _getPhotoUrl().isNotEmpty
                                          ? NetworkImage(_getPhotoUrl())
                                          : null,
                                      child: _getPhotoUrl().isEmpty
                                          ? Icon(Icons.person, size: 50, color: Colors.grey[500])
                                          : null,
                                    ),
                                  ),
                                  // Online Status Dot
                                  Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E), // Green 500
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                      ),
                                    ),
                                  )
                                ],
                              ),

                              const SizedBox(height: 16),
                              
                              // 3. Name & Phone
                              Text(
                                _userData?['full_name'] ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (_userData?['mobile_primary'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _userData?['mobile_primary'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _isDark ? Colors.white70 : Colors.grey[600],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),

                              // 4. TabBar (Integrated)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TabBar(
                                  controller: _tabController,
                                  labelColor: _isDark ? Colors.white : Colors.black87,
                                  unselectedLabelColor: _isDark ? Colors.white60 : Colors.grey[500],
                                  indicatorColor: _isDark ? Colors.white : Colors.black87,
                                  indicatorWeight: 3,
                                  indicatorSize: TabBarIndicatorSize.tab, // Full width
                                  dividerColor: Colors.transparent, // Remove line
                                  tabs: const [
                                    Tab(text: 'Personal Info'),
                                    Tab(text: 'KYC Details'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // -- Body Content --
                    Expanded(
                      child: RefreshIndicator(
                         onRefresh: _loadData,
                         child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPersonalInfoTab(),
                            _buildKycDetailsTab(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  String _formatDOB(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final d = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      final y = date.year.toString();
      return "$d/$m/$y";
    } catch (_) {
      return dateStr;
    }
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
              _buildInfoRow("Mobile", _userData?['mobile_primary'] ?? 'N/A'),
              _buildInfoRow("Username", _userData?['username'] ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            "Additional Details",
            [
              _buildInfoRow("Date of Birth", _formatDOB(_profileData?['date_of_birth'])),
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

          const SizedBox(height: 16),
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

  Widget _buildKycDetailsTab() {

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            "KYC Status",
            [
               // Custom Row with Badge for Profile Status
              _buildStatusRow(
                "Profile Status",
                _getProfileStatusDisplay(_profileData?['profile_status']),
                _profileData?['profile_status'] == 'VERIFIED',
              ),
              const SizedBox(height: 16),
              
              // Custom Row with Badge for KYC Status
              _buildStatusRow(
                "KYC Status",
                _getKycStatusDisplay(_profileData?['kyc_status']),
                _profileData?['kyc_status'] == 'VERIFIED',
              ),
              const SizedBox(height: 16),

              // Standard Rows
              _buildInfoRow(
                "Verification Method",
                _getKycMethodDisplay(_profileData?['verification_method']),
                null, 
                true // bold value
              ),
              if (_profileData?['kyc_verified_at'] != null)
                _buildInfoRow(
                   "Verified On", 
                   _formatDate(_profileData?['kyc_verified_at']),
                   null,
                   true
                ),
                
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



  Widget _buildInfoCard(String title, List<Widget> children) {
    // Dynamic Colors
    final cardColor = _isDark ? const Color(0xFF1F2937) : Colors.white;
    final titleColor = _isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = _isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16), // Modern Rounded
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: titleColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isVerified) {
    final labelColor = _isDark ? Colors.grey[400] : Colors.grey[600];
    final valueColor = _isDark ? Colors.white : Colors.black87;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isDark 
                 ? const Color(0xFF064E3B) // Dark Green BG
                 : const Color(0xFFE8F5E9), // Light Green BG
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isDark ? const Color(0xFF059669) : Colors.transparent, 
                width: 1
              )
            ),
            child: Text(
              value,
              style: TextStyle(
                color: _isDark ? const Color(0xFF6EE7B7) : const Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor, bool boldValue = false]) {
    final labelColor = _isDark ? Colors.grey[400] : Colors.grey[600];
    final defaultValueColor = _isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16), // Increased spacing
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: valueColor ?? defaultValueColor,
                fontWeight: (valueColor != null || boldValue) ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildHeaderIcon({required Widget child, required bool isDark}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }
}

