import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/session_controller.dart';
import '../../models/assignment.dart';
import '../support/report_issue_screen.dart';

class MyDutiesScreen extends StatefulWidget {
  final SessionController session;
  const MyDutiesScreen({super.key, required this.session});

  @override
  State<MyDutiesScreen> createState() => _MyDutiesScreenState();
}

class _MyDutiesScreenState extends State<MyDutiesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Assignment> _assignments = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDuties();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDuties() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await widget.session.api.getMyDuties();
      final List<Assignment> loaded = (data as List)
          .map((json) => Assignment.fromJson(json))
          .toList();
      
      if (mounted) {
        setState(() {
          _assignments = loaded;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Logic Helpers ---

  List<Assignment> get _currentDuties {
    return _assignments.where((a) => 
      a.status == 'PENDING' || 
      a.status == 'CONFIRMED' || 
      a.status == 'CHECK_IN' ||
      a.status == 'ACTIVE'
    ).toList();
  }

  List<Assignment> get _historyDuties {
    return _assignments.where((a) => 
      a.status == 'COMPLETED' || 
      a.status == 'CANCELLED' || 
      a.status == 'REJECTED'
    ).toList();
  }

  Future<void> _confirmAssignment(Assignment assignment) async {
    try {
      await widget.session.api.confirmAssignment(assignment.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Duty Confirmed!")),
      );
      _loadDuties(); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleLocationAction(Assignment assignment, bool isCheckIn) async {
    final examCenter = assignment.shiftCenter.center;
    final masterCenter = examCenter.masterCenter;

    double? targetLat;
    double? targetLong;
    int radius = 200;

    if (examCenter.latitude != null && examCenter.longitude != null) {
      targetLat = examCenter.latitude;
      targetLong = examCenter.longitude;
      radius = examCenter.geofenceRadiusMeters;
    } else if (masterCenter?.latitude != null && masterCenter?.longitude != null) {
      targetLat = masterCenter!.latitude;
      targetLong = masterCenter.longitude;
      radius = masterCenter.geofenceRadiusMeters;
    }

    if (targetLat == null || targetLong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Center location not configured."), backgroundColor: Colors.red),
      );
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw "Location permissions are denied";
      }
      if (permission == LocationPermission.deniedForever) throw "Location permissions are permanently denied.";

      String? selfiePath;
      if (isCheckIn) {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 600,
          imageQuality: 80,
        );
        if (photo == null) throw "Selfie is required to check in.";
        selfiePath = photo.path;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final dist = Geolocator.distanceBetween(
        position.latitude, position.longitude, targetLat, targetLong
      );

      if (dist > radius) {
        if (!mounted) return;
        showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
            title: const Text("Too Far"),
            content: Text("You are ${dist.toInt()}m away. Max allowed is ${radius}m."),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
          )
        );
        return; 
      }

      if (isCheckIn) {
        await widget.session.api.checkIn(assignment.uid, position.latitude, position.longitude, selfiePath);
      } else {
        await widget.session.api.checkOut(assignment.uid, position.latitude, position.longitude);
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isCheckIn ? "Checked In Successfully!" : "Checked Out Successfully!"), 
        backgroundColor: Colors.green
      ));
      _loadDuties();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Action Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFF6366F1); // Indigo
    final bg = isDark ? const Color(0xFF0C0E11) : Colors.grey[50];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        automaticallyImplyLeading: false, // No back button
        title: Text(
          "My Duties",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false, // Align left
        actions: [
          IconButton(
            icon: Icon(Icons.logout, size: 24, color: isDark ? Colors.white : Colors.black),
            onPressed: () => widget.session.logout(),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          indicatorWeight: 3,
          labelColor: accentColor,
          unselectedLabelColor: isDark ? Colors.grey[600] : Colors.grey[500],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "CURRENT"),
            Tab(text: "HISTORY"),
          ],
        ),
      ),
      body: _isLoading && _assignments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDutyList(_currentDuties, "No active duties assigned."),
                _buildDutyList(_historyDuties, "No history available."),
              ],
            ),
    );
  }

  Widget _buildDutyList(List<Assignment> list, String emptyMsg) {
    if (_error != null && list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Error: $_error", style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDuties, child: const Text("Retry"))
          ],
        ),
      );
    }

    if (list.isEmpty) {
      return Center(
        child: Text(
          emptyMsg,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDuties,
      child: ListView.builder(
        itemCount: list.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) => _buildDutyCard(list[index]),
      ),
    );
  }

  Widget _buildDutyCard(Assignment assignment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF161A22) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);

    final center = assignment.shiftCenter.center;
    final shift = assignment.shiftCenter.shift;
    final exam = assignment.shiftCenter.exam;

    // Status Styling
    final status = assignment.status.toUpperCase();
    final statusColor = _getStatusColor(status);
    final isPending = status == 'PENDING';
    final isActive = status == 'ACTIVE' || status == 'CHECK_IN' || status == 'CONFIRMED';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status + Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {}, // Optional menu
                  icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              exam.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Details Row: Date / Time
          _buildDetailRow(
            Icons.calendar_today_outlined,
            "${shift.startTime.substring(0, 5)} | ${shift.endTime.substring(0, 5)}", // Simplified for now
          ),
          
          // Details Row: Venue
          _buildDetailRow(
            Icons.location_on_outlined,
            "${center.clientCenterName}, ${center.masterCenter?.city ?? ''}",
          ),

          const SizedBox(height: 16),

          // Footer Action
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                if (isPending)
                  _buildPrimaryButton("CONFIRM DUTY", () => _confirmAssignment(assignment)),
                
                if (status == 'CONFIRMED')
                  _buildPrimaryButton("I HAVE REACHED (CHECK IN)", 
                      () => _handleLocationAction(assignment, true), 
                      color: Colors.green),

                if (assignment.isCheckedIn) ...[
                  _buildPrimaryButton("DUTY OVER (CHECK OUT)", 
                      () => _handleLocationAction(assignment, false), 
                      color: Colors.red),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => ReportIssueScreen(
                            session: widget.session,
                            assignment: assignment
                          ))
                        );
                      },
                      icon: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: const Text("Report Issue"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],

                if (!isActive && !isPending && !assignment.isCheckedIn)
                  _buildPrimaryButton("VIEW HISTORY", () {}, outline: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed, {Color? color, bool outline = false}) {
    final accentColor = color ?? const Color(0xFF6366F1);
    
    if (outline) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: accentColor.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            text,
            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'CONFIRMED': return Colors.green;
      case 'CHECK_IN': return Colors.purple;
      case 'ACTIVE': return Colors.blue;
      case 'COMPLETED': return Colors.teal;
      case 'CANCELLED': return Colors.red;
      case 'REJECTED': return Colors.red;
      default: return Colors.grey;
    }
  }
}