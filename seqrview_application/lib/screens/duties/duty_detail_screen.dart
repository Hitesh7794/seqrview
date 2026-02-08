import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as IO;
import 'package:dio/dio.dart';
import '../../app/session_controller.dart';
import '../../models/assignment.dart';

class DutyDetailScreen extends StatefulWidget {
  final SessionController session;
  final Assignment assignment;

  const DutyDetailScreen({
    super.key,
    required this.session,
    required this.assignment,
  });

  @override
  State<DutyDetailScreen> createState() => _DutyDetailScreenState();
}

class _DutyDetailScreenState extends State<DutyDetailScreen> {
  bool _isLoading = false;
  List<dynamic> _tasks = [];
  String? _error;
  Map<String, List<XFile>> _pendingFiles = {};

  bool get _isDark => widget.session.isDark;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Assuming GET /assignments/tasks/?assignment={uid} returns a list of AssignmentTask
      // If endpoint is different, we adjust. 
      // Based on views.py: AssignmentTaskViewSet filters by assignment__operator=user.
      // But we want tasks for THIS assignment. 
      // The viewset logic was: return qs.filter(assignment__operator=user). 
      // We can filter by ?assignment=uid if the viewset supports standard filtering or if we add it.
      // Standard ModelViewSet with django-filter usually supports it, but let's assume we might need to filter client-side or add filter backend.
      // Actually, let's try fetching and see. 
      // Wait, I need to make sure the backend supports filtering by assignment UID.
      // The viewset in views.py has `filter_backends`? No, it just has `get_queryset`.
      // It returns ALL tasks for the operator. So I can filter locally or add `assignment` filter param.
      // Adding param to `get_queryset` is better.
      
      final data = await widget.session.api.getAssignmentTasks(widget.assignment.uid);
      
      if (mounted) {
        setState(() {
          _tasks = data;
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

  Future<void> _completeTask(String taskUid, {List<String>? filePaths}) async {
    try {
      await widget.session.api.completeTask(taskUid, filePaths: filePaths);
      _loadTasks(); // Refresh
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task Completed!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_prettyError(e)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _isDark ? const Color(0xFF0C0E11) : Colors.grey[50];
    final cardColor = _isDark ? const Color(0xFF161A22) : Colors.white;
    final textColor = _isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: BackButton(color: textColor),
        title: Text("Duty Details", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
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
                          onPressed: _loadTasks,
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Duty Info Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
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
                            Text(
                              widget.assignment.shiftCenter.exam.name,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Role: ${widget.assignment.role.name}",
                              style: TextStyle(fontSize: 14, color: Colors.indigoAccent, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            _infoRow(Icons.calendar_today, "${widget.assignment.shiftCenter.shift.startTime} - ${widget.assignment.shiftCenter.shift.endTime}", textColor),
                            const SizedBox(height: 8),
                            _infoRow(Icons.location_on, widget.assignment.shiftCenter.center.clientCenterName, textColor),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Text("Checklist", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 12),

                      // Tasks List
                      if (_tasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text("No tasks assigned.", style: TextStyle(color: Colors.grey[600]))),
                        )
                      else
                        ..._tasks.map((task) => _buildTaskItem(task)).toList(),
                    ],
                  ),
                ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: color))),
      ],
    );
  }

  Future<void> _pickEvidence(String taskUid, String type) async {
      final picker = ImagePicker();
      XFile? file;
      if (type == 'VIDEO') {
        file = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 30));
      } else {
        file = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024, imageQuality: 80);
      }
      
      if (file != null) {
        setState(() {
           if (!_pendingFiles.containsKey(taskUid)) {
             _pendingFiles[taskUid] = [];
           }
           _pendingFiles[taskUid]!.add(file!);
        });
      }
  }

  Future<void> _submitEvidence(String taskUid) async {
      final files = _pendingFiles[taskUid];
      if (files == null || files.isEmpty) return;
      
      await _completeTask(taskUid, filePaths: files.map((f) => f.path).toList());
      
      setState(() {
          _pendingFiles.remove(taskUid);
      });
  }

  void _removePendingFile(String taskUid, int index) {
      setState(() {
          _pendingFiles[taskUid]?.removeAt(index);
      });
  }

  Widget _buildTaskItem(dynamic task) {
    bool isCompleted = task['status'] == 'COMPLETED';
    bool isMandatory = task['is_mandatory'] == true;
    String taskType = task['task_type'] ?? 'CHECKLIST';
    List<XFile> pending = _pendingFiles[task['uid']] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Checkbox (Only for CHECKLIST) or Status Icon
                  if (taskType == 'CHECKLIST')
                    Transform.scale(
                      scale: 1.2,
                      child: Checkbox(
                        value: isCompleted,
                        onChanged: isCompleted ? null : (v) {
                          if (v == true) _completeTask(task['uid']);
                        },
                        activeColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    )
                  else if (isCompleted)
                     const Padding(
                       padding: EdgeInsets.all(8.0),
                       child: Icon(Icons.check_circle, color: Colors.green, size: 28),
                     ),
                  
                  const SizedBox(width: 8),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['task_name'] ?? "Unknown Task",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isCompleted ? Colors.grey : Colors.black87,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (task['description'] != null && task['description'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              task['description'],
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ),
                        if (isMandatory)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red[100]!),
                            ),
                            child: Text(
                              "Required",
                              style: TextStyle(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Action Buttons for Photo/Video
                  if (!isCompleted && taskType != 'CHECKLIST') ...[
                      IconButton(
                        onPressed: () => _pickEvidence(task['uid'], taskType),
                        icon: Icon(
                           taskType == 'VIDEO' ? Icons.videocam_outlined : Icons.add_a_photo_outlined,
                           color: Colors.indigo,
                        ),
                        tooltip: "Add Evidence",
                      ),
                  ]
              ],
            ),

            // Pending Evidence Preview
            if (pending.isNotEmpty && !isCompleted)
               Container(
                 margin: const EdgeInsets.only(top: 12),
                 height: 80,
                 child: ListView.builder(
                   scrollDirection: Axis.horizontal,
                   itemCount: pending.length + 1, // +1 for submit button flow or just list
                   itemBuilder: (context, index) {
                      if (index == pending.length) {
                          // Submit Button
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: ElevatedButton.icon(
                                onPressed: () => _submitEvidence(task['uid']),
                                icon: const Icon(Icons.send, size: 16),
                                label: const Text("Submit"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                ),
                              ),
                            ),
                          );
                      }
                      
                      final file = pending[index];
                      // Simple thumbnail based on type
                      bool isVideo = file.path.toLowerCase().endsWith('.mp4') || taskType == 'VIDEO'; // rough check

                      return Stack(
                        children: [
                          Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                image: isVideo ? null : DecorationImage(
                                   image: FileImage(IO.File(file.path)), // Need dart:io import
                                   fit: BoxFit.cover
                                )
                            ),
                            child: isVideo ? const Center(child: Icon(Icons.videocam, color: Colors.grey)) : null,
                          ),
                          Positioned(
                            top: -4, right: 4,
                            child: GestureDetector(
                              onTap: () => _removePendingFile(task['uid'], index),
                              child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                            ),
                          )
                        ],
                      );
                   }
                 ),
               ),
          ],
        ),
      ),
    );
  }
}
