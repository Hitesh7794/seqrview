import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/session_controller.dart';
import '../../models/assignment.dart';
import '../../models/incident_category.dart';

class ReportIssueScreen extends StatefulWidget {
  final SessionController session;
  final Assignment assignment;

  const ReportIssueScreen({
    super.key,
    required this.session,
    required this.assignment,
  });

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  bool _isLoading = false;
  List<IncidentCategory> _categories = [];
  
  // Form State
  String? _selectedCategoryUid;
  String _selectedPriority = 'MEDIUM';
  final _descriptionController = TextEditingController();
  final List<String> _imagePaths = [];
  
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.session.api.getIncidentCategories();
      setState(() {
        _categories = (data as List).map((e) => IncidentCategory.fromJson(e)).toList();
        if (_categories.isNotEmpty) {
          _selectedCategoryUid = _categories.first.uid;
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
         widget.session.logout();
         return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_prettyError(e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _pickImage() async {
    if (_imagePaths.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max 3 photos allowed")));
      return;
    }
    
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      imageQuality: 80,
    );
    
    if (photo != null) {
      setState(() {
        _imagePaths.add(photo.path);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imagePaths.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryUid == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      await widget.session.api.reportIncident(
        assignmentId: widget.assignment.uid,
        categoryId: _selectedCategoryUid!,
        priority: _selectedPriority,
        description: _descriptionController.text,
        imagePaths: _imagePaths,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Issue Reported Successfully!"), backgroundColor: Colors.green),
      );
      Navigator.pop(context); // Close screen
      
    } catch (e) {
      if (mounted) {
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
           widget.session.logout();
           return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_prettyError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report Issue")),
      body: _isLoading && _categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Assignment Info Card
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(widget.assignment.examName),
                        subtitle: Text("Center: ${widget.assignment.centerName}"),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 1. Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryUid,
                      decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
                      items: _categories.map((c) => DropdownMenuItem(
                        value: c.uid,
                        child: Text(c.name),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryUid = val),
                    ),
                    const SizedBox(height: 16),
                    
                    // 2. Priority
                    const Text("Priority:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        _buildPriorityRadio('LOW', 'Low', Colors.green),
                        _buildPriorityRadio('MEDIUM', 'Medium', Colors.orange),
                        _buildPriorityRadio('HIGH', 'High', Colors.red),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 3. Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: "Description", 
                        border: OutlineInputBorder(),
                        hintText: "Describe the issue in detail..."
                      ),
                      validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // 4. Attachments
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Photos (Max 3):", style: TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(onPressed: _pickImage, icon: const Icon(Icons.camera_alt, color: Colors.blue)),
                      ],
                    ),
                    if (_imagePaths.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imagePaths.length,
                          itemBuilder: (ctx, i) => Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  image: DecorationImage(
                                    image: FileImage(File(_imagePaths[i])),
                                    fit: BoxFit.cover
                                  )
                                ),
                              ),
                              Positioned(
                                right: 0, top: 0,
                                child: GestureDetector(
                                  onTap: () => _removeImage(i),
                                  child: Container(
                                    color: Colors.white.withOpacity(0.7), 
                                    child: const Icon(Icons.close, color: Colors.red, size: 20)
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitReport,
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text("Submit Report"),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPriorityRadio(String value, String label, Color color) {
    return Row(
      children: [
        Radio<String>(
          value: value,
          groupValue: _selectedPriority,
          onChanged: (val) => setState(() => _selectedPriority = val!),
          activeColor: color,
        ),
        Text(label, style: TextStyle(color: _selectedPriority == value ? color : Colors.black)),
        const SizedBox(width: 8),
      ],
    );
  }
}
