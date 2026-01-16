import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../app/session_controller.dart';
import '../models/assignment.dart';
import 'duties/my_duties_screen.dart';



class HomeScreen extends StatefulWidget {
  final SessionController session;
  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _userData;
  List<Assignment> _recentDuties = [];
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
          _recentDuties = loaded
              .where((a) => a.status == 'PENDING' || a.status == 'CONFIRMED')
              .take(2)
              .toList();
              
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is DioException
              ? (e.response?.data?['detail']?.toString() ?? "Failed to load data")
              : "Failed to load data: $e";
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
                        
                        // Recent Duties Section
                        const Text(
                          "Upcoming Duties",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_recentDuties.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  "No upcoming duties assigned.",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            ),
                          )
                        else
                          ..._recentDuties.map((assignment) {
                            final shift = assignment.shiftCenter.shift;
                            final center = assignment.shiftCenter.center;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: assignment.status == 'CONFIRMED' 
                                      ? Colors.green.shade100 
                                      : Colors.orange.shade100,
                                  child: Icon(
                                    assignment.status == 'CONFIRMED' ? Icons.check : Icons.access_time,
                                    color: assignment.status == 'CONFIRMED' ? Colors.green : Colors.orange,
                                  ),
                                ),
                                title: Text(assignment.shiftCenter.exam.name),
                                subtitle: Text(
                                  "${shift.startTime.substring(0, 5)} @ ${center.clientCenterName}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {
                                  // Navigate to MyDuties tab via MainScreen if possible, 
                                  // or push Screen. For simplicity here we push screen.
                                  // Since we have tabs now, ideally we switch tabs, but pushing is fine for deep linking behavior.
                                   Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => MyDutiesScreen(session: widget.session),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
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

