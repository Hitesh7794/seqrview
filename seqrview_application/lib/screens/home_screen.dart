import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../app/session_controller.dart';
import '../models/assignment.dart'; // Restored
import '../widgets/global_support_button.dart';
import 'duties/my_duties_screen.dart';
import '../core/config.dart';



class HomeScreen extends StatefulWidget {
  final SessionController session;
  final Function(int)? onNavigateToTab;
  final bool isActive;

  const HomeScreen({
    super.key, 
    required this.session, 
    this.onNavigateToTab,
    this.isActive = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Theme State
  bool get _isDark => widget.session.isDark;

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_update);
    _loadData();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If tab just became active, refresh data
    if (widget.isActive && !oldWidget.isActive) {
      _loadData();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_update);
    super.dispose();
  }
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _userData;
  List<Assignment> _recentDuties = [];
  bool _loading = true;
  String? _error;
  
  // Insights State
  String _totalHours = "0h";
  String _attendance = "0%";



  Future<void> _loadData() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Fetch profile, user data, and duties in parallel
      final profileRes = await widget.session.api.dio.get('/api/operators/profile/');
      final userRes = await widget.session.api.dio.get('/api/identity/me/');
      final dutiesRes = await widget.session.api.getMyDuties();

      if (mounted) {
        setState(() {
          _profileData = profileRes.data as Map<String, dynamic>?;
          _userData = userRes.data as Map<String, dynamic>?;
          
          final List<Assignment> loaded = (dutiesRes as List)
              .map((json) => Assignment.fromJson(json))
              .toList();
          // Filter for pending/confirmed and take top 2
          // Filter for pending/confirmed and take top 5
          _recentDuties = loaded
              .where((a) => a.status == 'PENDING' || a.status == 'CONFIRMED')
              .take(5) 
              .toList();

          // -- Calculate Insights --
          // 1. Total Hours (Sum of duration of COMPLETED duties)
          final completed = loaded.where((a) => a.status == 'COMPLETED').toList();
          double totalMinutes = 0;
          for (var duty in completed) {
            try {
              // Parse HH:mm:ss
              final start = _parseTime(duty.shiftCenter.shift.startTime);
              final end = _parseTime(duty.shiftCenter.shift.endTime);
              // Handle overnight shifts if needed (end < start) -> add 24h
              int diff = end.difference(start).inMinutes;
              if (diff < 0) diff += 24 * 60;
              totalMinutes += diff;
            } catch (e) {
              // Ignore parse errors
            }
          }
          final hours = (totalMinutes / 60).toStringAsFixed(1);
          _totalHours = "${hours}h";

          // 2. Attendance (Completed / (Completed + Absent + Cancelled) ?)
          // For now, assuming "Past Duties" are what matters. 
          // If we don't have full history including missed, we might just show % of Assigned that are Completed.
          // Let's rely on Profile Data if available, else calc logic.
          if (_profileData != null && _profileData!.containsKey('attendance_score')) {
             _attendance = "${_profileData!['attendance_score']}%";
          } else {
             // Fallback: Just show 100% if no negative data, or calc if possible.
             // Let's assume 100% for positive reinforcement until we have 'ABSENT' status.
             _attendance = completed.isNotEmpty ? "100%" : "0%";
          }
              
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
           // Session Expired - Redirect to Login
           widget.session.logout(); // Clears tokens
           // Use GoRouter to force navigation back to start
           // We assume the router listens to session, but explicit nav is safer here if not reactive
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
    
    // Dynamic Theme Colors
    final isDark = widget.session.isDark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6); // Grey 900 vs Grey 100
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[500];
    
    // Header Colors
    final headerGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark 
          ? [const Color(0xFF1F2937), const Color(0xFF111827)] // Dark Gradient
          : [const Color(0xFFFFFFFF), const Color(0xFFE5E7EB)], // White -> Light Grey
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 48, color: subTextColor),
                        const SizedBox(height: 16),
                        Text(
                          "Oops!", 
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!, 
                          textAlign: TextAlign.center,
                          style: TextStyle(color: subTextColor)
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                          ),
                        )
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    // -- 1. Background Header --
                    Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: headerGradient,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                        boxShadow: [
                          if (!isDark) 
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10, offset: const Offset(0, 5)
                            )
                        ]
                      ),
                    ),

                    // -- 2. Scrollable Content --
                    SafeArea(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // -- Custom App Bar --
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                    Image.asset(
                                      'assets/images/logo.png',
                                      height: 32, // Adjusted for AppBar
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GlobalSupportButton(isDark: _isDark),
                                        const SizedBox(width: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                            onPressed: () {
                                              // TODO: Open Notifications
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Notifications coming soon!")),
                                              );
                                            },
                                            icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white : const Color(0xFF111827)),
                                            tooltip: 'Notifications',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                              ),
                            ),
                            
                            const SizedBox(height: 30),

                            // -- Profile Card (Overlapping) --
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(24),
                                border: isDark ? null : Border.all(color: Colors.grey[200]!, width: 1), // Border for Light Mode
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), // Stronger shadow
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // "Welcome Back!" Note
                                        Text(
                                          "Welcome Back!",
                                          style: TextStyle(
                                            fontSize: 24, // Bold and prominent
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF111827),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Name
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _userData?['full_name'] ?? 'Loading...',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_userData?['is_verified'] == true) ...[
                                              const SizedBox(width: 6),
                                              const Icon(Icons.verified, color: Colors.blue, size: 18),
                                            ]
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 4),
                                        
                                        // Phone
                                        Text(
                                          _userData?['mobile_primary'] ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: subTextColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 16),

                                  // Avatar (Moved to Right)
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E7FF), // ID: light indigo bg
                                      shape: BoxShape.circle,
                                    ),
                                    child: CircleAvatar(
                                      radius: 35,
                                      backgroundColor: const Color(0xFF6366F1), // Indigo
                                      backgroundImage: _getPhotoUrl().isNotEmpty
                                          ? NetworkImage(_getPhotoUrl())
                                          : null,
                                      onBackgroundImageError: _getPhotoUrl().isNotEmpty 
                                          ? (_, __) {} 
                                          : null,
                                      child: _getPhotoUrl().isEmpty
                                          ? const Icon(Icons.person, color: Colors.white, size: 36)
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            // -- Upcoming Duties --
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Upcoming Duties",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                     widget.onNavigateToTab?.call(1);
                                  },
                                  child: const Text("All Duties"),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 10),

                            // -- Duties List OR Empty State --
                            if (_recentDuties.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                                decoration: BoxDecoration(
                                  border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!, width: 1.5),
                                  borderRadius: BorderRadius.circular(24),
                                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.5),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.calendar_today, size: 32, color: subTextColor),
                                    ),
                                    // const SizedBox(height: 16),
                                    // Text(
                                    //   "Rest & Recharge",
                                    //   style: TextStyle(
                                    //     fontWeight: FontWeight.bold,
                                    //     fontSize: 16,
                                    //     color: textColor,
                                    //   ),
                                    // ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "No upcoming duties assigned\nto you at this moment.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: subTextColor, height: 1.5),
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: _loadData,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF3E8FF), // Light purple
                                        foregroundColor: const Color(0xFF7E22CE), // Dark purple
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                      child: const Text("Check Updates"),
                                    )
                                  ],
                                ),
                              )
                            else
                              ..._recentDuties.map((assignment) {
                                final shift = assignment.shiftCenter.shift;
                                final center = assignment.shiftCenter.center;
                                return Card(
                                  color: cardColor,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: assignment.status == 'CONFIRMED' 
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.orange.withOpacity(0.2),
                                      child: Icon(
                                        assignment.status == 'CONFIRMED' ? Icons.check : Icons.access_time,
                                        color: assignment.status == 'CONFIRMED' ? Colors.green : Colors.orange,
                                      ),
                                    ),
                                    title: Text(
                                      assignment.shiftCenter.exam.name,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        "${shift.startTime.substring(0, 5)} @ ${center.clientCenterName}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: subTextColor),
                                      ),
                                    ),
                                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor),
                                    onTap: () {
                                         // Navigate to Duties Tab
                                        widget.onNavigateToTab?.call(1);
                                    },
                                  ),
                                );
                              }).toList(),

                            const SizedBox(height: 30),

                            // -- Quick Insights --
                            Text(
                              "Quick Insights",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInsightCard(
                                    icon: Icons.timer,
                                    color: Colors.blue,
                                    value: _totalHours,
                                    label: "Total Hours",
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildInsightCard(
                                    icon: Icons.check_circle,
                                    color: Colors.green,
                                    value: _attendance,
                                    label: "Attendance",
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  DateTime _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final now = DateTime.now();
      return DateTime(
        now.year, now.month, now.day, 
        int.parse(parts[0]), 
        int.parse(parts[1]), 
        parts.length > 2 ? int.parse(parts[2].split('.')[0]) : 0
      );
    } catch (_) {
      return DateTime.now();
    }
  }

  String _getPhotoUrl() {
    final photo = _userData?['photo'];
    if (photo == null || photo.toString().isEmpty) return '';
    final photoStr = photo.toString();
    if (photoStr.startsWith('http://') || photoStr.startsWith('https://')) {
      return photoStr;
    }
    if (photoStr.startsWith('/')) {
      return '$apiBaseUrl$photoStr';
    }
    return '$apiBaseUrl/media/$photoStr';
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : color.withOpacity(0.05), // Dark card or Light tinted
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: isDark ? color.withOpacity(0.2) : Colors.white,
               shape: BoxShape.circle,
             ),
             child: Icon(icon, color: color, size: 20),
           ),
           const SizedBox(height: 12),
           Text(
             value,
             style: TextStyle(
               fontSize: 22,
               fontWeight: FontWeight.bold,
               color: isDark ? Colors.white : const Color(0xFF1F2937),
             ),
           ),
           const SizedBox(height: 4),
           Text(
             label,
             style: TextStyle(
               fontSize: 14,
               color: isDark ? Colors.grey[400] : Colors.grey[600],
             ),
           ),
        ],
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

