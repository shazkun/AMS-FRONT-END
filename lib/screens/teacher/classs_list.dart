import 'dart:convert';
import 'package:attsys/screens/teacher/qr_scan.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────
const _kBreakpoint = 720.0;

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
// ClassStudentsScreen — root
// ─────────────────────────────────────────────────────────────────────────────
class ClassStudentsScreen extends StatefulWidget {
  final String classId;
  final String className;
  const ClassStudentsScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  List<dynamic> students = [];
  bool isLoading = true;
  String _search = '';

  // summary stats
  int get totalStudents => students.length;
  int get presentToday =>
      students.where((s) => s['last_status'] == 'Present').length;
  int get absentToday =>
      students.where((s) => s['last_status'] == 'Absent').length;
  int get lateToday => students.where((s) => s['last_status'] == 'Late').length;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadStudents() async {
    setState(() => isLoading = true);
    try {
      final token = await _getToken();
      final res = await http
          .get(
            Uri.parse(ApiConfig.teacherClassStudents(widget.classId)),
            headers: ApiConfig.headers(token),
          )
          .timeout(ApiConfig.timeout);
      if (res.statusCode == 200) {
        setState(() {
          students = json.decode(res.body) as List;
          isLoading = false;
        });
      } else {
        _showSnack(
          'Failed to load students: ${res.statusCode}',
          success: false,
        );
        setState(() => isLoading = false);
      }
    } catch (e) {
      _showSnack('Error: $e', success: false);
      setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: success ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<dynamic> get _filtered {
    if (_search.isEmpty) return students;
    final q = _search.toLowerCase();
    return students.where((s) {
      final name =
          '${s['firstname'] ?? ''} ${s['suffix'] ?? ''} ${s['surname'] ?? ''}'
              .toLowerCase();
      final lrn = (s['lrn'] ?? '').toString().toLowerCase();
      return name.contains(q) || lrn.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isDesktop = constraints.maxWidth >= _kBreakpoint;
        return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: _kBg,
      body: Row(
        children: [
          // ── Left info panel ────────────────────────────────────────────────
          Container(
            width: 240,
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
                  // Back + class name header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                  size: 16,
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
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.people_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.className,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Class Roster',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      color: Colors.white.withOpacity(0.2),
                      height: 20,
                    ),
                  ),

                  // Stat cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        _RailStat(
                          icon: Icons.people_rounded,
                          label: 'Total Students',
                          value: '$totalStudents',
                          loading: isLoading,
                        ),
                        const SizedBox(height: 6),
                        _RailStat(
                          icon: Icons.check_circle_rounded,
                          label: 'Present Today',
                          value: '$presentToday',
                          loading: isLoading,
                          valueColor: Colors.greenAccent.shade200,
                        ),
                        const SizedBox(height: 6),
                        _RailStat(
                          icon: Icons.cancel_rounded,
                          label: 'Absent Today',
                          value: '$absentToday',
                          loading: isLoading,
                          valueColor: Colors.redAccent.shade100,
                        ),
                        const SizedBox(height: 6),
                        _RailStat(
                          icon: Icons.access_time_rounded,
                          label: 'Late Today',
                          value: '$lateToday',
                          loading: isLoading,
                          valueColor: Colors.orangeAccent.shade200,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Refresh
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    child: InkWell(
                      onTap: _loadStudents,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Refresh',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content area ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar with search
                Container(
                  height: 60,
                  color: _kCard,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Text(
                        'Student Roster',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1a1a2e),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText: 'Search by name or LRN…',
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _kAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_filtered.length} student${_filtered.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: _kAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
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
                          : _filtered.isEmpty
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

  Widget _buildDesktopEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.people_outline, size: 56, color: _kAccent),
        ),
        const SizedBox(height: 20),
        Text(
          students.isEmpty
              ? 'No students enrolled yet'
              : 'No results for "$_search"',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1a1a2e),
          ),
        ),
        if (students.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Students will appear here once enrolled',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ],
    ),
  );

  Widget _buildDesktopGrid() {
    return RefreshIndicator(
      onRefresh: _loadStudents,
      color: _kAccent,
      child: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 320,
          childAspectRatio: 1.6,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _DesktopStudentCard(student: _filtered[i]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout() {
    void openQRScanner(String classId, String className) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QRScanScreen(classId: classId, className: className),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadStudents,
              ),
              IconButton(
                icon: const Icon(Icons.scanner, color: Colors.white),
                onPressed:
                    () => openQRScanner(widget.classId, widget.className),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: _kGrad),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.people_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Class Roster',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.className,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _MobileStatBadge(
                              icon: Icons.group_rounded,
                              label: '$totalStudents total',
                            ),
                            const SizedBox(width: 8),
                            _MobileStatBadge(
                              icon: Icons.check_circle_rounded,
                              label: '$presentToday present',
                              color: Colors.greenAccent.shade200,
                            ),
                            const SizedBox(width: 8),
                            _MobileStatBadge(
                              icon: Icons.cancel_rounded,
                              label: '$absentToday absent',
                              color: Colors.redAccent.shade100,
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

          // Search bar
          SliverToBoxAdapter(
            child: Container(
              color: _kCard,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search by name or LRN…',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: _kAccent,
                    size: 18,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
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
                    vertical: 11,
                    horizontal: 14,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: const Divider(height: 1, color: Color(0xFFE8EAF0)),
          ),

          // Student list
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _kAccent)),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      students.isEmpty
                          ? Icons.person_off_rounded
                          : Icons.search_off_rounded,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      students.isEmpty
                          ? 'No students enrolled yet'
                          : 'No results for "$_search"',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) =>
                      _MobileStudentCard(student: _filtered[i], index: i),
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kAccent,
        onPressed: () => openQRScanner(widget.classId, widget.className),
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop student card (grid)
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopStudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  const _DesktopStudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final fullName =
        '${student['firstname'] ?? ''} ${student['suffix'] ?? ''} ${student['surname'] ?? ''}'
            .trim()
            .replaceAll(RegExp(r'  +'), ' ');
    final lrn = student['lrn']?.toString() ?? '—';
    final sex = student['sex'] as String?;
    final lastStatus = student['last_status'] as String?;
    final statusColor = switch (lastStatus) {
      'Present' => Colors.green,
      'Absent' => Colors.red,
      'Late' => Colors.orange,
      'Excused' => Colors.blue,
      _ => Colors.grey,
    };
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    gradient: _kGrad,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1a1a2e),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'LRN: $lrn',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (lastStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      lastStatus,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                if (sex != null) ...[
                  Icon(
                    sex == 'Male' ? Icons.male_rounded : Icons.female_rounded,
                    size: 13,
                    color:
                        sex == 'Male'
                            ? Colors.blue.shade400
                            : Colors.pink.shade400,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    sex,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 10),
                ],
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        lastStatus != null ? statusColor : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile student card (list tile)
// ─────────────────────────────────────────────────────────────────────────────
class _MobileStudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final int index;
  const _MobileStudentCard({required this.student, required this.index});

  @override
  Widget build(BuildContext context) {
    final fullName =
        '${student['firstname'] ?? ''} ${student['suffix'] ?? ''} ${student['surname'] ?? ''}'
            .trim()
            .replaceAll(RegExp(r'  +'), ' ');
    final lrn = student['lrn']?.toString() ?? '—';
    final sex = student['sex'] as String?;
    final lastStatus = student['last_status'] as String?;
    final statusColor = switch (lastStatus) {
      'Present' => Colors.green,
      'Absent' => Colors.red,
      'Late' => Colors.orange,
      'Excused' => Colors.blue,
      _ => Colors.grey,
    };
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: _kGrad,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1a1a2e),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'LRN: $lrn',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (sex != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          sex == 'Male'
                              ? Icons.male_rounded
                              : Icons.female_rounded,
                          size: 14,
                          color:
                              sex == 'Male'
                                  ? Colors.blue.shade400
                                  : Colors.pink.shade400,
                        ),
                        Text(
                          sex,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Status badge
            if (lastStatus != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  lastStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'No record',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rail stat widget (shared desktop)
// ─────────────────────────────────────────────────────────────────────────────
class _RailStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool loading;
  final Color? valueColor;
  const _RailStat({
    required this.icon,
    required this.label,
    required this.value,
    this.loading = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: valueColor ?? Colors.white70, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        loading
            ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
            : Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile stat badge
// ─────────────────────────────────────────────────────────────────────────────
class _MobileStatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MobileStatBadge({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color ?? Colors.white, size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}
