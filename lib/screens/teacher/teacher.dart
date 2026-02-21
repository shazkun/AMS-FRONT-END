import 'dart:convert';
import 'package:attsys/widgets/logout.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';
import 'classs_list.dart'; // Assuming this is ClassStudentsScreen
import 'create_section.dart';
import 'qr_scan.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  List<dynamic> myClasses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyClasses();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadMyClasses() async {
    setState(() => isLoading = true);

    try {
      final token = await _getToken();
      if (token == null) throw 'Token missing';

      final res = await http
          .get(
            Uri.parse(ApiConfig.teacherClasses),
            headers: ApiConfig.headers(token),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        final classes = json.decode(res.body) as List;
        setState(() {
          myClasses = classes;
          isLoading = false;
        });
      } else {
        _showError('Failed to load classes: ${res.statusCode}');
      }
    } catch (e) {
      _showError('Network error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openQRScanner(String classId, String className) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRScanScreen(classId: classId, className: className),
      ),
    );
  }

  void _openCreateSection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateSectionScreen()),
    ).then((_) => _loadMyClasses());
  }

  void _openClassStudents(String classId, String className) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ClassStudentsScreen(classId: classId, className: className),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea), // same as login/register
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom header (replacing default AppBar for better gradient integration)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    const Text(
                      'My Classes',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Refresh',
                      onPressed: _loadMyClasses,
                    ),
                    LogoutButton(),
                  ],
                ),
              ),

              // Main content area
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadMyClasses,
                  color: const Color(0xFF667eea),
                  backgroundColor: Colors.white,
                  child:
                      isLoading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                          : myClasses.isEmpty
                          ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height - 180,
                              child: _buildEmptyState(),
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: myClasses.length,
                            itemBuilder: (context, index) {
                              final cls = myClasses[index];
                              return _buildClassCard(cls);
                            },
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton:
          myClasses.isNotEmpty
              ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FloatingActionButton.extended(
                  onPressed: _openCreateSection,
                  elevation: 6,
                  highlightElevation: 12,
                  hoverElevation: 12,
                  backgroundColor:
                      Colors.blue, // Keep transparent to show gradient
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  icon: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: const Text(
                    'New Class',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
              : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.class_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No classes yet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first class to start managing students and attendance',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.85),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _openCreateSection,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ).copyWith(
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minHeight: 56),
                  child: const Text(
                    'Create First Class',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls) {
    final studentCount = cls['student_count'] ?? 0;
    final gradeSection =
        'Grade ${cls['grade_level']}${cls['section'] != null ? ' - ${cls['section']}' : ''}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _openClassStudents(cls['id'].toString(), cls['name']),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.class_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cls['name'] ?? 'Unnamed Class',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            gradeSection,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildInfoChip(
                      Icons.calendar_today_rounded,
                      cls['school_year'] ?? '—',
                      const Color(0xFFFF9800),
                    ),
                    _buildInfoChip(
                      Icons.people_rounded,
                      '$studentCount student${studentCount != 1 ? 's' : ''}',
                      const Color(0xFF4CAF50),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            () => _openClassStudents(
                              cls['id'].toString(),
                              cls['name'],
                            ),
                        icon: const Icon(Icons.people_rounded, size: 20),
                        label: const Text('Students'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                            color: Color(0xFF667eea),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            () => _openQRScanner(
                              cls['id'].toString(),
                              cls['name'],
                            ),
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 20,
                        ),
                        label: const Text('Scan QR'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
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
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
