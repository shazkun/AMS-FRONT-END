import 'package:attsys/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../providers/auth_provider.dart';

class CreateSectionScreen extends StatefulWidget {
  const CreateSectionScreen({super.key});

  @override
  State<CreateSectionScreen> createState() => _CreateSectionScreenState();
}

class _CreateSectionScreenState extends State<CreateSectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sectionController = TextEditingController();
  final _subjectController = TextEditingController();
  final _schoolYearController = TextEditingController(text: '2025-2026');

  String? _selectedGrade;
  final List<String> _gradeLevels = List.generate(
    12,
    (i) => (i + 1).toString(),
  );

  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  List<String> _selectedDays = [];

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoading = false;
  String? _error;

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 30),
    );
    if (picked != null && mounted) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 30),
    );
    if (picked != null && mounted) setState(() => _endTime = picked);
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGrade == null) {
      setState(() => _error = 'Please select grade level');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = await auth.getToken();

      final body = {
        'name': _nameController.text.trim(),
        'gradeLevel': _selectedGrade,
        'section':
            _sectionController.text.trim().isEmpty
                ? null
                : _sectionController.text.trim(),
        'subject':
            _subjectController.text.trim().isEmpty
                ? null
                : _subjectController.text.trim(),
        'schoolYear': _schoolYearController.text.trim(),
        'days': _selectedDays,
        'startTime': _startTime != null ? _formatTimeOfDay(_startTime!) : null,
        'endTime': _endTime != null ? _formatTimeOfDay(_endTime!) : null,
      };

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/teacher/classes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Class created successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        final err = json.decode(res.body)['message'] ?? 'Unknown error';
        setState(() => _error = 'Failed: $err');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Create New Class",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Set up your class details",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Form card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              label: "Class Name *",
                              icon: Icons.class_rounded,
                              validator:
                                  (v) =>
                                      v?.trim().isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                            const SizedBox(height: 20),

                            DropdownButtonFormField<String>(
                              value: _selectedGrade,
                              decoration: InputDecoration(
                                labelText: "Grade Level *",
                                prefixIcon: const Icon(
                                  Icons.school_rounded,
                                  color: Color(0xFF667eea),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF667eea),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                              ),
                              items:
                                  _gradeLevels
                                      .map(
                                        (g) => DropdownMenuItem(
                                          value: g,
                                          child: Text('Grade $g'),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (v) => setState(() => _selectedGrade = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),

                            _buildTextField(
                              controller: _sectionController,
                              label: "Section (optional)",
                              icon: Icons.group_rounded,
                            ),
                            const SizedBox(height: 20),

                            _buildTextField(
                              controller: _subjectController,
                              label: "Subject (optional)",
                              icon: Icons.book_rounded,
                            ),
                            const SizedBox(height: 20),

                            _buildTextField(
                              controller: _schoolYearController,
                              label: "School Year * (e.g. 2025-2026)",
                              icon: Icons.calendar_month_rounded,
                              validator:
                                  (v) =>
                                      v?.trim().isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                            const SizedBox(height: 28),

                            const Text(
                              'Class Days',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children:
                                  _weekDays.map((day) {
                                    final selected = _selectedDays.contains(
                                      day,
                                    );
                                    return FilterChip(
                                      label: Text(day),
                                      selected: selected,
                                      onSelected: (sel) {
                                        setState(() {
                                          if (sel) {
                                            _selectedDays.add(day);
                                          } else {
                                            _selectedDays.remove(day);
                                          }
                                        });
                                      },
                                      backgroundColor:
                                          selected
                                              ? const Color(
                                                0xFF667eea,
                                              ).withOpacity(0.1)
                                              : null,
                                      selectedColor: const Color(0xFF667eea),
                                      checkmarkColor: Colors.white,
                                      labelStyle: TextStyle(
                                        color:
                                            selected
                                                ? Colors.white
                                                : Colors.black87,
                                      ),
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 28),

                            const Text(
                              'Class Time',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),

                            OutlinedButton(
                              onPressed: _pickStartTime,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    color: Color(0xFF667eea),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      _startTime == null
                                          ? 'Start Time'
                                          : 'Start: ${_formatTimeOfDay(_startTime!)}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            OutlinedButton(
                              onPressed: _pickEndTime,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    color: Color(0xFF667eea),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      _endTime == null
                                          ? 'End Time'
                                          : 'End: ${_formatTimeOfDay(_endTime!)}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ).copyWith(
                                foregroundColor: WidgetStateProperty.all(
                                  Colors.white,
                                ),
                                overlayColor: WidgetStateProperty.all(
                                  Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF667eea),
                                      Color(0xFF764ba2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  constraints: const BoxConstraints(
                                    minHeight: 56,
                                  ),
                                  child:
                                      _isLoading
                                          ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                          : const Text(
                                            "Create Class",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Back link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Changed your mind? ",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Back to Dashboard",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF667eea)),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
      ),
      validator: validator,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sectionController.dispose();
    _subjectController.dispose();
    _schoolYearController.dispose();
    super.dispose();
  }
}
