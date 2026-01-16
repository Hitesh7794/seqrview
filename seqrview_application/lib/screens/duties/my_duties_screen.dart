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

class _MyDutiesScreenState extends State<MyDutiesScreen> {
  bool _isLoading = false;
  List<Assignment> _assignments = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDuties();
  }

  Future<void> _loadDuties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await widget.session.api.getMyDuties();
      final List<Assignment> loaded = (data as List)
          .map((json) => Assignment.fromJson(json))
          .toList();
      
      setState(() {
        _assignments = loaded;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAssignment(Assignment assignment) async {
    try {
      await widget.session.api.confirmAssignment(assignment.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Duty Confirmed!")),
      );
      _loadDuties(); // Refresh
    } catch (e) {
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

    // Priority 1: Exam Center
    if (examCenter.latitude != null && examCenter.longitude != null) {
      targetLat = examCenter.latitude;
      targetLong = examCenter.longitude;
      radius = examCenter.geofenceRadiusMeters;
    } 
    // Priority 2: Master Center
    else if (masterCenter?.latitude != null && masterCenter?.longitude != null) {
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

    setState(() => _isLoading = true);

    try {
      // 1. Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw "Location permissions are denied";
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw "Location permissions are permanently denied.";
      }

      // 2. Selfie Step (Only for Check-In)
      String? selfiePath;
      if (isCheckIn) {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 600, // Optimize size
          imageQuality: 80,
        );
        
        if (photo == null) {
          throw "Selfie is required to check in.";
        }
        selfiePath = photo.path;
      }

      // 3. Get Location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Reduced from high for speed
        timeLimit: const Duration(seconds: 10), // Prevent infinite hang
      );

      // 4. Validate Distance
      final dist = Geolocator.distanceBetween(
        position.latitude, 
        position.longitude, 
        targetLat, 
        targetLong
      );

      if (dist > radius) {
        // Soft Check Failed
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

      // 5. Call API
      if (isCheckIn) {
        await widget.session.api.checkIn(assignment.uid, position.latitude, position.longitude, selfiePath);
      } else {
        await widget.session.api.checkOut(assignment.uid, position.latitude, position.longitude);
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCheckIn ? "Checked In Successfully!" : "Checked Out Successfully!"), 
          backgroundColor: Colors.green
        ),
      );
      _loadDuties();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Action Failed: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Duties"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDuties,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error"))
              : _assignments.isEmpty
                  ? const Center(child: Text("No duties assigned yet."))
                  : ListView.builder(
                      itemCount: _assignments.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final assignment = _assignments[index];
                        final center = assignment.shiftCenter.center;
                        final shift = assignment.shiftCenter.shift;
                        final exam = assignment.shiftCenter.exam;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Chip(
                                      label: Text(assignment.status, style: const TextStyle(fontSize: 12)),
                                      backgroundColor: _getStatusColor(assignment.status),
                                    ),
                                    Text(
                                      shift.startTime.substring(0, 5), // HH:MM
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  exam.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "${center.clientCenterName} (${center.clientCenterCode})",
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text("Role: ${assignment.role.name}"),
                                if (center.masterCenter?.city.isNotEmpty == true)
                                  Text("Location: ${center.masterCenter!.city}"),
                                
                                const SizedBox(height: 16),
                                
                                if (assignment.status == 'PENDING')
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _confirmAssignment(assignment),
                                      child: const Text("Confirm Duty"),
                                    ),
                                  ),
                                
                                  if (assignment.isConfirmed) ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          // TODO: Navigate to Detail Screen
                                        },
                                        child: const Text("View Details"),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _handleLocationAction(assignment, true),
                                        icon: const Icon(Icons.location_on),
                                        label: const Text("I Have Reached (Check In)"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                  
                                  if (assignment.isCheckedIn) ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _handleLocationAction(assignment, false),
                                        icon: const Icon(Icons.exit_to_app),
                                        label: const Text("Duty Over (Check Out)"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
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
                                        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                        label: const Text("Report Issue"),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange.shade100;
      case 'CONFIRMED': return Colors.green.shade100;
      case 'CHECK_IN': return Colors.purple.shade100;
      case 'COMPLETED': return Colors.blue.shade100;
      case 'CANCELLED': return Colors.red.shade100;
      default: return Colors.grey.shade100;
    }
  }
}