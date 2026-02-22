import 'dart:convert';
import 'package:attsys/widgets/logout.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import 'classs_list.dart';
import 'create_section.dart';
import 'qr_scan.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const _kBreakpoint = 900.0;

const _kGrad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
);

const _kAccent = Color(0xFF667eea);
const _kPurple = Color(0xFF764ba2);
const _kBg = Color(0xFFF0F2FA);
const _kCard = Colors.white;

// ─────────────────────────────────────────────────────────────────────────────
// Root Dashboard
// ─────────────────────────────────────────────────────────────────────────────
class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  List<dynamic> myClasses = [];
  bool isLoading = true;
  String _searchQuery = '';

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
        setState(() {
          myClasses = json.decode(res.body) as List;
          isLoading = false;
        });
      } else {
        _showError('Failed to load classes: ${res.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      _showError('Network error: $e');
      setState(() => isLoading = false);
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

  List<dynamic> get _filteredClasses {
    if (_searchQuery.isEmpty) return myClasses;
    final q = _searchQuery.toLowerCase();
    return myClasses.where((cls) {
      final name = (cls['name'] ?? '').toString().toLowerCase();
      final grade = (cls['grade_level'] ?? '').toString().toLowerCase();
      final section = (cls['section'] ?? '').toString().toLowerCase();
      final subject = (cls['subject'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          grade.contains(q) ||
          section.contains(q) ||
          subject.contains(q);
    }).toList();
  }

  int get _totalStudents => myClasses.fold(
    0,
    (sum, cls) => sum + ((cls['student_count'] ?? 0) as int),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isDesktop = constraints.maxWidth >= _kBreakpoint;
        return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESKTOP LAYOUT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: _kBg,
      body: Row(
        children: [
          // ── Left rail ──────────────────────────────────────────────────────
          Container(
            width: 220,
            decoration: const BoxDecoration(
              gradient: _kGrad,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 20,
                  offset: Offset(4, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo area
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Teacher',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'Dashboard',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Stats cards
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _RailStatCard(
                          icon: Icons.class_rounded,
                          label: 'Classes',
                          value: myClasses.length,
                          loading: isLoading,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(height: 6),
                        _RailStatCard(
                          icon: Icons.people_rounded,
                          label: 'Students',
                          value: _totalStudents,
                          loading: isLoading,
                          color: Colors.greenAccent,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      color: Colors.white.withOpacity(0.2),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Nav items (static, single view)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.class_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'My Classes',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.circle, color: Colors.white, size: 6),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Refresh + Create + Logout
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Column(
                      children: [
                        _RailAction(
                          icon: Icons.add_circle_rounded,
                          label: 'New Class',
                          onTap: _openCreateSection,
                          highlight: true,
                        ),
                        const SizedBox(height: 6),
                        _RailAction(
                          icon: Icons.refresh_rounded,
                          label: 'Refresh',
                          onTap: _loadMyClasses,
                        ),
                        const SizedBox(height: 6),
                        const _RailLogoutWidget(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content area ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 60,
                  color: _kCard,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Text(
                        'My Classes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1a1a2e),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Search bar
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search classes…',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: _kAccent,
                              size: 18,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: _kAccent,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 14,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Attendance Management System',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE8EAF0)),
                Expanded(
                  child:
                      isLoading
                          ? const Center(
                            child: CircularProgressIndicator(color: _kAccent),
                          )
                          : _filteredClasses.isEmpty
                          ? _buildDesktopEmptyState()
                          : _buildDesktopGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopGrid() {
    return RefreshIndicator(
      onRefresh: _loadMyClasses,
      color: _kAccent,
      child: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          childAspectRatio: 1.35,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredClasses.length,
        itemBuilder:
            (context, index) => _DesktopClassCard(
              cls: _filteredClasses[index],
              onStudents:
                  () => _openClassStudents(
                    _filteredClasses[index]['id'].toString(),
                    _filteredClasses[index]['name'],
                  ),
              onScan:
                  () => _openQRScanner(
                    _filteredClasses[index]['id'].toString(),
                    _filteredClasses[index]['name'],
                  ),
            ),
      ),
    );
  }

  Widget _buildDesktopEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.class_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            myClasses.isEmpty
                ? 'No classes yet'
                : 'No results for "$_searchQuery"',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          if (myClasses.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Create your first class to get started',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openCreateSection,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Class'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: Container(
          decoration: const BoxDecoration(gradient: _kGrad),
          child: SafeArea(
            child: Column(
              children: [
                // Top row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'My Classes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _loadMyClasses,
                      ),
                      const LogoutButton(),
                    ],
                  ),
                ),
                // Stat chips + search
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      _MobileStatChip(
                        icon: Icons.class_rounded,
                        label: '${myClasses.length} Classes',
                        loading: isLoading,
                      ),
                      const SizedBox(width: 8),
                      _MobileStatChip(
                        icon: Icons.people_rounded,
                        label: '$_totalStudents Students',
                        loading: isLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search classes…',
                prefixIcon: const Icon(Icons.search, color: _kAccent, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kAccent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 0, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredClasses.length} class${_filteredClasses.length != 1 ? 'es' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child:
                isLoading
                    ? const Center(
                      child: CircularProgressIndicator(color: _kAccent),
                    )
                    : _filteredClasses.isEmpty
                    ? _buildMobileEmptyState()
                    : RefreshIndicator(
                      onRefresh: _loadMyClasses,
                      color: _kAccent,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                        itemCount: _filteredClasses.length,
                        itemBuilder:
                            (context, index) => _MobileClassCard(
                              cls: _filteredClasses[index],
                              onStudents:
                                  () => _openClassStudents(
                                    _filteredClasses[index]['id'].toString(),
                                    _filteredClasses[index]['name'],
                                  ),
                              onScan:
                                  () => _openQRScanner(
                                    _filteredClasses[index]['id'].toString(),
                                    _filteredClasses[index]['name'],
                                  ),
                            ),
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSection,
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Class',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildMobileEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.class_rounded, size: 56, color: _kAccent),
            ),
            const SizedBox(height: 24),
            Text(
              myClasses.isEmpty
                  ? 'No classes yet'
                  : 'No results for "$_searchQuery"',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1a1a2e),
              ),
            ),
            if (myClasses.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tap + New Class to create your first class',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop Class Card
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopClassCard extends StatelessWidget {
  final Map<String, dynamic> cls;
  final VoidCallback onStudents;
  final VoidCallback onScan;

  const _DesktopClassCard({
    required this.cls,
    required this.onStudents,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final studentCount = cls['student_count'] ?? 0;
    final gradeSection =
        'Grade ${cls['grade_level']}${cls['section'] != null ? ' · ${cls['section']}' : ''}';

    return InkWell(
      onTap: onStudents,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kAccent, _kPurple],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.class_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cls['name'] ?? 'Unnamed',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF1a1a2e),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          gradeSection,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _SmallChip('${cls['school_year'] ?? '—'}', Colors.indigo),
                  _SmallChip(
                    '$studentCount student${studentCount != 1 ? 's' : ''}',
                    Colors.teal,
                  ),
                  if (cls['subject'] != null)
                    _SmallChip('${cls['subject']}', Colors.orange),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onStudents,
                      icon: const Icon(Icons.people_rounded, size: 14),
                      label: const Text(
                        'Students',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: _kAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onScan,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 14),
                      label: const Text(
                        'Scan QR',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        backgroundColor: _kAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Class Card
// ─────────────────────────────────────────────────────────────────────────────
class _MobileClassCard extends StatelessWidget {
  final Map<String, dynamic> cls;
  final VoidCallback onStudents;
  final VoidCallback onScan;

  const _MobileClassCard({
    required this.cls,
    required this.onStudents,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final studentCount = cls['student_count'] ?? 0;
    final gradeSection =
        'Grade ${cls['grade_level']}${cls['section'] != null ? ' · ${cls['section']}' : ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onStudents,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kAccent, _kPurple],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.class_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cls['name'] ?? 'Unnamed Class',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1a1a2e),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          gradeSection,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _SmallChip(cls['school_year'] ?? '—', Colors.indigo),
                  _SmallChip(
                    '$studentCount student${studentCount != 1 ? 's' : ''}',
                    Colors.teal,
                  ),
                  if (cls['subject'] != null)
                    _SmallChip('${cls['subject']}', Colors.orange),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onStudents,
                      icon: const Icon(Icons.people_rounded, size: 18),
                      label: const Text('Students'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: _kAccent, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onScan,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text('Scan QR'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: _kAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rail sub-widgets (desktop)
// ─────────────────────────────────────────────────────────────────────────────
class _RailStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final bool loading;
  final Color color;
  const _RailStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.loading,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          loading
              ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
              : Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
        ],
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              highlight
                  ? Colors.white.withOpacity(0.22)
                  : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border:
              highlight
                  ? Border.all(color: Colors.white.withOpacity(0.4))
                  : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailLogoutWidget extends StatelessWidget {
  const _RailLogoutWidget();
  @override
  Widget build(BuildContext context) => const LogoutButton();
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile sub-widgets
// ─────────────────────────────────────────────────────────────────────────────
class _MobileStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  const _MobileStatChip({
    required this.icon,
    required this.label,
    required this.loading,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          loading
              ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 1.5,
                ),
              )
              : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small chip
// ─────────────────────────────────────────────────────────────────────────────
class _SmallChip extends StatelessWidget {
  final String label;
  final MaterialColor color;
  const _SmallChip(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
