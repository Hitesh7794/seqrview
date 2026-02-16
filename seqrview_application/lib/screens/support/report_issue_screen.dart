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
    final isDark = widget.session.isDark;
    final backgroundColor = isDark ? const Color(0xFF0C0E11) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? Colors.grey[800] : Colors.grey[300];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Report Issue", style: TextStyle(color: textColor)),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.indigo,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.white),
        elevation: 0,
      ),
      body: _isLoading && _categories.isEmpty
          ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.indigo))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Assignment Info Card
                    Card(
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: borderColor ?? Colors.transparent),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.info_outline, color: isDark ? Colors.blueAccent : Colors.indigo),
                        title: Text(
                          widget.assignment.examName,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Center: ${widget.assignment.centerName}",
                          style: TextStyle(color: subTextColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 1. Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryUid,
                      dropdownColor: cardColor,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Category", 
                        labelStyle: TextStyle(color: subTextColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(
                        value: c.uid,
                        child: Text(c.name, style: TextStyle(color: textColor)),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryUid = val),
                    ),
                    const SizedBox(height: 20),
                    
                    // 2. Priority
                    Text("Selection Priority:", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildPriorityRadio('LOW', 'Low', Colors.green, isDark),
                          _buildPriorityRadio('MEDIUM', 'Medium', Colors.orange, isDark),
                          _buildPriorityRadio('HIGH', 'High', Colors.red, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 3. Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Description", 
                        labelStyle: TextStyle(color: subTextColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor!),
                        ),
                        hintText: "Describe the issue in detail...",
                        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      ),
                      validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // 4. Attachments
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Photos (Max 3):", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        IconButton(
                          onPressed: _pickImage, 
                          icon: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                          tooltip: "Add Photo",
                        ),
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
                                margin: const EdgeInsets.only(right: 12),
                                width: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor!),
                                  image: DecorationImage(
                                    image: FileImage(File(_imagePaths[i])),
                                    fit: BoxFit.cover
                                  )
                                ),
                              ),
                              Positioned(
                                right: 12, top: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(i),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ), 
                                    child: const Icon(Icons.close, color: Colors.white, size: 16)
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF222B45) : Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text("Submit Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPriorityRadio(String value, String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: _selectedPriority,
          onChanged: (val) => setState(() => _selectedPriority = val!),
          activeColor: color,
        ),
        Text(
          label, 
          style: TextStyle(
            color: _selectedPriority == value ? color : (isDark ? Colors.grey[400] : Colors.black87),
            fontWeight: _selectedPriority == value ? FontWeight.bold : FontWeight.normal,
          )
        ),
      ],
    );
  }
}
