import 'package:attsys/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
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

  // ── Platform ─────────────────────────────────────────────────────────────────
  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  // ── Time helpers ─────────────────────────────────────────────────────────────
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

  String _formatTimeLabel(TimeOfDay? t, String placeholder) {
    if (t == null) return placeholder;
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  // ── Submit ────────────────────────────────────────────────────────────────────
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

  // ── Root build ────────────────────────────────────────────────────────────────
  static const double _kDesktopBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _kDesktopBreakpoint;
    return isWide ? _buildDesktopLayout() : _buildMobileLayout();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT  — full-screen gradient card (original style, refined)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
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
          child: Column(
            children: [
              // Mobile app bar row
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Create New Class',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _mobileCard(
                          children: [
                            _mobileField(
                              controller: _nameController,
                              label: 'Class Name',
                              icon: Icons.class_rounded,
                              validator:
                                  (v) =>
                                      v?.trim().isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                            const SizedBox(height: 16),
                            _mobileGradeDropdown(),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _mobileField(
                                    controller: _sectionController,
                                    label: 'Section',
                                    icon: Icons.group_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _mobileField(
                                    controller: _schoolYearController,
                                    label: 'School Year',
                                    icon: Icons.calendar_month_rounded,
                                    validator:
                                        (v) =>
                                            v?.trim().isEmpty ?? true
                                                ? 'Required'
                                                : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _mobileField(
                              controller: _subjectController,
                              label: 'Subject (optional)',
                              icon: Icons.book_rounded,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        _mobileCard(
                          children: [
                            _mobileSectionLabel('Class Days'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  _weekDays.map((day) {
                                    final sel = _selectedDays.contains(day);
                                    return GestureDetector(
                                      onTap:
                                          () => setState(
                                            () =>
                                                sel
                                                    ? _selectedDays.remove(day)
                                                    : _selectedDays.add(day),
                                          ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              sel
                                                  ? const Color(0xFF667eea)
                                                  : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color:
                                                sel
                                                    ? const Color(0xFF667eea)
                                                    : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          day,
                                          style: TextStyle(
                                            color:
                                                sel
                                                    ? Colors.white
                                                    : Colors.black87,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        _mobileCard(
                          children: [
                            _mobileSectionLabel('Class Time'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _mobileTimeButton(
                                    label: _formatTimeLabel(
                                      _startTime,
                                      'Start Time',
                                    ),
                                    icon: Icons.access_time_rounded,
                                    onTap: _pickStartTime,
                                    hasValue: _startTime != null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _mobileTimeButton(
                                    label: _formatTimeLabel(
                                      _endTime,
                                      'End Time',
                                    ),
                                    icon: Icons.access_time_rounded,
                                    onTap: _pickEndTime,
                                    hasValue: _endTime != null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        _mobileSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _mobileSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF667eea),
      ),
    );
  }

  Widget _mobileField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF667eea), size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        isDense: true,
      ),
      validator: validator,
    );
  }

  Widget _mobileGradeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGrade,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Grade Level',
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: const Icon(
          Icons.school_rounded,
          color: Color(0xFF667eea),
          size: 20,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        isDense: true,
      ),
      items:
          _gradeLevels
              .map((g) => DropdownMenuItem(value: g, child: Text('Grade $g')))
              .toList(),
      onChanged: (v) => setState(() => _selectedGrade = v),
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _mobileTimeButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool hasValue,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasValue ? const Color(0xFF667eea) : Colors.grey.shade200,
            width: hasValue ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF667eea), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: hasValue ? Colors.black87 : Colors.grey.shade500,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ).copyWith(foregroundColor: WidgetStateProperty.all(Colors.white)),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 54),
          child:
              _isLoading
                  ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                  : const Text(
                    'Create Class',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DESKTOP / WINDOWS LAYOUT  — sidebar + main panel, flat modern look
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Row(
        children: [
          // ── Left sidebar ──────────────────────────────────────────────────
          Container(
            width: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Back',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.class_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'New Class',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in the details to create a new class section.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.75),
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),

                    // Quick tips
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tips',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...[
                            'Class name and grade level are required.',
                            'School year format: 2025-2026.',
                            'You can select multiple class days.',
                          ].map(
                            (tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 5),
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Colors.white60,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tip,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          Expanded(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 40,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page title
                      const Text(
                        'Class Details',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1D2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set up your new class section below.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Row 1: Name + Grade ──────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _desktopField(
                              controller: _nameController,
                              label: 'Class Name',
                              hint: 'e.g. English 7-A',
                              icon: Icons.class_rounded,
                              validator:
                                  (v) =>
                                      v?.trim().isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: _desktopGradeDropdown()),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Row 2: Section + Subject + School Year ───────────
                      Row(
                        children: [
                          Expanded(
                            child: _desktopField(
                              controller: _sectionController,
                              label: 'Section',
                              hint: 'e.g. Rizal',
                              icon: Icons.group_rounded,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _desktopField(
                              controller: _subjectController,
                              label: 'Subject',
                              hint: 'e.g. Mathematics',
                              icon: Icons.book_rounded,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _desktopField(
                              controller: _schoolYearController,
                              label: 'School Year',
                              hint: '2025-2026',
                              icon: Icons.calendar_month_rounded,
                              validator:
                                  (v) =>
                                      v?.trim().isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ── Class Days ────────────────────────────────────────
                      _desktopSectionHeader(
                        'Class Days',
                        Icons.date_range_rounded,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children:
                            _weekDays.map((day) {
                              final sel = _selectedDays.contains(day);
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: InkWell(
                                  onTap:
                                      () => setState(
                                        () =>
                                            sel
                                                ? _selectedDays.remove(day)
                                                : _selectedDays.add(day),
                                      ),
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 64,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          sel
                                              ? const Color(0xFF667eea)
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            sel
                                                ? const Color(0xFF667eea)
                                                : Colors.grey.shade300,
                                      ),
                                      boxShadow:
                                          sel
                                              ? [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF667eea,
                                                  ).withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                              : [],
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          day,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color:
                                                sel
                                                    ? Colors.white
                                                    : Colors.grey.shade600,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (sel) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Colors.white70,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // ── Class Time ────────────────────────────────────────
                      _desktopSectionHeader(
                        'Class Time',
                        Icons.access_time_rounded,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _desktopTimeButton(
                            label: _formatTimeLabel(_startTime, 'Start Time'),
                            onTap: _pickStartTime,
                            hasValue: _startTime != null,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '→',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          _desktopTimeButton(
                            label: _formatTimeLabel(_endTime, 'End Time'),
                            onTap: _pickEndTime,
                            hasValue: _endTime != null,
                          ),
                        ],
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 36),

                      // ── Actions ───────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 16,
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 36,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                              shadowColor: const Color(
                                0xFF667eea,
                              ).withOpacity(0.4),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Create Class',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
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
        ],
      ),
    );
  }

  // ── Desktop helpers ───────────────────────────────────────────────────────────

  Widget _desktopSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF667eea), size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D2E),
          ),
        ),
      ],
    );
  }

  Widget _desktopField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1D2E)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF667eea), size: 18),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 13,
              horizontal: 14,
            ),
            isDense: true,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _desktopGradeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Grade Level',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedGrade,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1D2E)),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.school_rounded,
              color: Color(0xFF667eea),
              size: 18,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 13,
              horizontal: 14,
            ),
            isDense: true,
          ),
          items:
              _gradeLevels
                  .map(
                    (g) => DropdownMenuItem(value: g, child: Text('Grade $g')),
                  )
                  .toList(),
          onChanged: (v) => setState(() => _selectedGrade = v),
          validator: (v) => v == null ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _desktopTimeButton({
    required String label,
    required VoidCallback onTap,
    required bool hasValue,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasValue ? const Color(0xFF667eea) : Colors.grey.shade200,
            width: hasValue ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_rounded,
              color: hasValue ? const Color(0xFF667eea) : Colors.grey.shade400,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color:
                    hasValue ? const Color(0xFF1A1D2E) : Colors.grey.shade400,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
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
