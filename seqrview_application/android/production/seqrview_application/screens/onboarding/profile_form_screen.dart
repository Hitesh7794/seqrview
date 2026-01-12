import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app/session_controller.dart';

class ProfileFormScreen extends StatefulWidget {
  final SessionController session;
  const ProfileFormScreen({super.key, required this.session});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  DateTime? _dob;
  String _gender = "M";

  bool _loading = false;
  String? _error;

  String _prettyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      return "Network/API error (${e.response?.statusCode ?? 'no status'})";
    }
    return e.toString();
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime(now.year - 10, 12, 31),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    final fn = _firstName.text.trim();
    final ln = _lastName.text.trim();

    if (fn.isEmpty || ln.isEmpty) {
      setState(() => _error = "Please enter first name and last name");
      return;
    }
    if (_dob == null) {
      setState(() => _error = "Please select Date of Birth");
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      // 1) update user name (me endpoint must support PATCH)
      await widget.session.api.dio.patch(
        '/api/identity/me/',
        data: {"first_name": fn, "last_name": ln},
      );

      // 2) update operator profile
      await widget.session.api.dio.patch(
        '/api/operators/profile/',
        data: {"date_of_birth": _fmtDate(_dob!), "gender": _gender},
      );

      await widget.session.bootstrap();
    } catch (e) {
      setState(() => _error = _prettyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dobText = _dob == null ? "Select DOB" : _fmtDate(_dob!);

    return Scaffold(
      appBar: AppBar(title: const Text("Complete Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: "First Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: "Last Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _pickDob,
                    child: Text(dobText),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _gender,
                  items: const [
                    DropdownMenuItem(value: "M", child: Text("Male")),
                    DropdownMenuItem(value: "F", child: Text("Female")),
                    DropdownMenuItem(value: "O", child: Text("Other")),
                  ],
                  onChanged: _loading ? null : (v) => setState(() => _gender = v ?? "M"),
                ),
              ],
            ),

            const SizedBox(height: 12),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.red.withOpacity(0.08),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Save & Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
