import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/session_controller.dart';
import '../../models/assignment.dart';
import '../../models/assignment.dart';
import '../support/report_issue_screen.dart';
import 'duty_detail_screen.dart';

class MyDutiesScreen extends StatefulWidget {
  final SessionController session;
  final bool isActive;

  const MyDutiesScreen({
    super.key, 
    required this.session,
    this.isActive = false,
  });

  @override
  State<MyDutiesScreen> createState() => _MyDutiesScreenState();
}

class _MyDutiesScreenState extends State<MyDutiesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Assignment> _assignments = [];
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
    
    // Refresh data when switching tabs (User Request)
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadDuties();
      }
    });

    _loadDuties();
  }

  @override
  void didUpdateWidget(MyDutiesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh when switching to this main tab
    if (widget.isActive && !oldWidget.isActive) {
      _loadDuties();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_update);
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
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
           widget.session.logout();
           return; 
        }
        setState(() {
          _error = _prettyError(e);
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
  
  String _prettyError(Object e) {
    if (e is String) return e;
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.connectionError) {
        return "Please check your internet connection.";
      }
      if (e.response?.statusCode == 500) {
        return "Server is currently unavailable.";
      }
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
         msg = data['detail']?.toString() ?? data['message']?.toString();
      }
      if (msg != null && msg.isNotEmpty) {
          // Sanitize
          final lower = msg.toLowerCase();
          if (lower.contains("surepass") || 
              lower.contains("authkey")) {
            return "Service unavailable.";
          }
          return msg;
      }
    }
    return "Something went wrong. Please try again.";
  }

  // --- Logic Helpers ---

  bool _isExpired(Assignment a) {
    if (a.shiftCenter.shift.workDate.isEmpty) return false;
    try {
      // Parse Work Date (YYYY-MM-DD)
      final datePart = DateTime.parse(a.shiftCenter.shift.workDate);
      
      // Parse End Time (HH:MM:SS)
      final timeParts = a.shiftCenter.shift.endTime.split(':');
      final endDateTime = DateTime(
        datePart.year, datePart.month, datePart.day,
        int.parse(timeParts[0]), int.parse(timeParts[1])
      );
      
      return DateTime.now().isAfter(endDateTime);
    } catch (e) {
      return false;
    }
  }

  List<Assignment> get _currentDuties {
    return _assignments.where((a) {
      final isStatusActive = a.status == 'PENDING' || 
                             a.status == 'CONFIRMED' || 
                             a.status == 'CHECK_IN' ||
                             a.status == 'ACTIVE';
      
      // If status is active but time expired, don't show in current
      if (isStatusActive && _isExpired(a)) return false;
      
      return isStatusActive;
    }).toList();
  }

  List<Assignment> get _historyDuties {
    return _assignments.where((a) {
      final isStatusCompleted = a.status == 'COMPLETED' || 
                                a.status == 'CANCELLED' || 
                                a.status == 'REJECTED';
                                
      // Show in history if completed OR if expired (even if status is technically active)
      return isStatusCompleted || _isExpired(a);
    }).toList();
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
        SnackBar(content: Text(_prettyError(e)), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleLocationAction(Assignment assignment, bool isCheckIn) async {
    final examCenter = assignment.shiftCenter.center;
    final masterCenter = examCenter.masterCenter;
    final exam = assignment.shiftCenter.exam;

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

    // Confirmation Dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCheckIn ? "Confirm Check-In" : "Confirm Check-Out"),
        content: Text("Are you sure you want to ${isCheckIn ? 'check in' : 'check out'} now?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("NO"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCheckIn ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("YES"),
          ),
        ],
      ),
    );

    if (confirm != true) return;



    try {
      // 1. Permissions (Must be before loading)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw "Location permissions are denied";
      }
      if (permission == LocationPermission.deniedForever) throw "Location permissions are permanently denied.";

      // 2. Selfie (Interactive - Must be before loading)
      String? selfiePath;
      if (isCheckIn && exam.isSelfieEnabled) {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 600,
          imageQuality: 80,
        );
        if (photo == null) return; // User cancelled camera
        selfiePath = photo.path;
      }

      // 3. Show Loading Dialog (Everything after here is background)
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: _isDark ? const Color(0xFF1F2937) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      isCheckIn ? "Verifying Identity..." : "Processing...",
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.w600,
                        color: _isDark ? Colors.white : Colors.black87
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Fetching location & syncing...",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

      try {
        // 4. Get Position
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 30),
        ).catchError((e) {
          throw "Could not get your location. Please ensure GPS is on.";
        });

        // 5. Distance check
        final dist = Geolocator.distanceBetween(
          position.latitude, position.longitude, targetLat, targetLong
        );

        if (exam.isGeofencingEnabled && dist > radius) {
          if (mounted) Navigator.pop(context); // Close loading
          if (mounted) {
            showDialog(
              context: context, 
              builder: (ctx) => AlertDialog(
                title: const Text("Too Far"),
                content: Text("You are ${dist.toInt()}m away from the center. Max allowed is ${radius}m."),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
              )
            );
          }
          return; 
        }

        // 6. Call API
        if (isCheckIn) {
          await widget.session.api.checkIn(assignment.uid, position.latitude, position.longitude, selfiePath);
        } else {
          await widget.session.api.checkOut(assignment.uid, position.latitude, position.longitude);
        }

        // 7. Success
        if (mounted) Navigator.pop(context); // Close loading
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isCheckIn ? "Checked In Successfully!" : "Checked Out Successfully!"), 
            backgroundColor: Colors.green
          ));
          _loadDuties();
        }

      } catch (e) {
        if (mounted) Navigator.pop(context); // Close loading
        rethrow;
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_prettyError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _launchMap(double lat, double long) async {
    final googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$long");
    final appleMapsUrl = Uri.parse("https://maps.apple.com/?q=$lat,$long");
    final geoUrl = Uri.parse("geo:$lat,$long?q=$lat,$long");

    try {
      if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl);
      } else if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open maps."), backgroundColor: Colors.red),
        );
      }
      print("Map Launch Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // final isDark = Theme.of(context).brightness == Brightness.dark; // OLD
    final isDark = _isDark; // NEW
    final accentColor = const Color(0xFF6366F1); // Indigo
    final bg = isDark ? const Color(0xFF0C0E11) : Colors.grey[50];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        automaticallyImplyLeading: false, // No back button
        title: Image.asset(
          'assets/images/logo.png',
          height: 32,
        ),
        centerTitle: false, // Align left
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24, color: isDark ? Colors.white : Colors.black),
            onPressed: _isLoading ? null : _loadDuties,
            tooltip: "Refresh Duties",
          ),

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
                  onPressed: _loadDuties,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
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
    final isDark = _isDark;
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
    
    // Check Date for Map
    final lat = center.latitude ?? center.masterCenter?.latitude;
    final long = center.longitude ?? center.masterCenter?.longitude;
    final hasLocation = lat != null && long != null;

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DutyDetailScreen(
                  session: widget.session,
                  assignment: assignment,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status Badge (No 3 Dots)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                  ],
                ),
              ),

              // Bold Center Name (with Map Icon if location available)
              InkWell(
                onTap: hasLocation ? () => _launchMap(lat!, long!) : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontFamily: 'Outfit', // Match app theme if possible
                                ),
                                children: [
                                  TextSpan(text: center.clientCenterName),
                                  TextSpan(
                                    text: " (${center.clientCenterCode})",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.normal,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (hasLocation)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.location_on, size: 30, color: Colors.blue),
                            )
                        ],
                      ),
                      if (assignment.centerAddress != null && assignment.centerAddress!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            assignment.centerAddress!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 4),

              // Time & Date
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Text(
                      "${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)} | ${shift.workDate}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              
              // Role & Exam Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                     Expanded(
                      child: Text(
                        "${assignment.role.name} • ${exam.name}",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
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
                      if (_isExpired(assignment) || assignment.isCompleted)
                        _buildTaskSummary(assignment)
                      else ...[
                        _buildPrimaryButton("DUTY OVER (CHECK OUT)", 
                            () => _handleLocationAction(assignment, false), 
                            color: Colors.red),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DutyDetailScreen(
                                        session: widget.session,
                                        assignment: assignment,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.checklist, size: 18),
                                label: const Text("View Tasks"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? Colors.white : Colors.black87,
                                  side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
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
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],

                    if (!isActive && !isPending && !assignment.isCheckedIn)
                      _buildPrimaryButton("VIEW HISTORY", () {}, outline: true),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildTaskSummary(Assignment assignment) {
    final doneCount = assignment.tasks.where((t) => t.isDone).length;
    final totalCount = assignment.tasks.length;
    final accentColor = _getStatusColor(assignment.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDark ? Colors.blueGrey.withOpacity(0.1) : Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Task Summary",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _isDark ? Colors.white : Colors.blueGrey[800],
                ),
              ),
              Text(
                "$doneCount / $totalCount Done",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: doneCount == totalCount ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...assignment.tasks.map((task) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 14,
                  color: task.isDone ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.taskName,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isDark ? Colors.grey[400] : Colors.grey[700],
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
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