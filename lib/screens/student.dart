import 'dart:convert';
import 'package:attsys/widgets/logout.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/auth_provider.dart';
import '../config/api_config.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  List<dynamic> enrolledClasses = [];
  List<dynamic> attendanceRecords = [];
  Map<String, dynamic>? profile;
  String? selectedClassId;
  String? selectedClassName;

  Map<String, int> stats = {'Present': 0, 'Absent': 0, 'Late': 0, 'Excused': 0};
  int totalSessions = 0;
  double attendanceRate = 0.0;
  int currentStreak = 0;
  int longestStreak = 0;

  bool isLoadingClasses = true;
  bool isLoadingAttendance = false;
  bool isLoadingProfile = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
    _loadEnrolledClasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadProfile() async {
    setState(() => isLoadingProfile = true);

    try {
      final token = await _getToken();
      final res = await http
          .get(
            Uri.parse(ApiConfig.studentProfile),
            headers: ApiConfig.headers(token),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        setState(() {
          profile = json.decode(res.body);
          isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() => isLoadingProfile = false);
    }
  }

  String _generateQrPayload(String classId) {
    if (profile == null) return '';
    final lrn = profile!['lrn'];
    final surname = profile!['surname'];
    final firstname = profile!['firstname'];
    return '$surname,$firstname|lrn:$lrn|class:$classId';
  }

  void _showQrCodeDialog(String classId, String className) {
    final qrPayload = _generateQrPayload(classId);

    if (qrPayload.isEmpty || profile == null) {
      _showError('Unable to generate QR code');
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.qr_code_2,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      className,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${profile!['firstname']} ${profile!['suffix'] ?? ''} ${profile!['surname']}'
                          .trim(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'LRN: ${profile!['lrn']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 240,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.blue.shade700,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.green.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Show this QR code to your teacher to mark attendance',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _loadEnrolledClasses() async {
    setState(() => isLoadingClasses = true);

    try {
      final token = await _getToken();
      final res = await http
          .get(
            Uri.parse(ApiConfig.studentClasses),
            headers: ApiConfig.headers(token),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          enrolledClasses = data;
          isLoadingClasses = false;
        });

        if (data.isNotEmpty) {
          _selectClass(data[0]['id'].toString(), data[0]['name']);
        }
      } else {
        _showError('Failed to load classes');
      }
    } catch (e) {
      _showError('Network error: $e');
    }
  }

  Future<void> _selectClass(String classId, String className) async {
    setState(() {
      selectedClassId = classId;
      selectedClassName = className;
      isLoadingAttendance = true;
      attendanceRecords = [];
      stats = {'Present': 0, 'Absent': 0, 'Late': 0, 'Excused': 0};
      totalSessions = 0;
      attendanceRate = 0.0;
      currentStreak = 0;
      longestStreak = 0;
    });

    try {
      final token = await _getToken();
      final uri = Uri.parse(
        ApiConfig.studentAttendance,
      ).replace(queryParameters: {'classId': classId});

      final res = await http
          .get(uri, headers: ApiConfig.headers(token))
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        final records = json.decode(res.body);
        _calculateStats(records);

        setState(() {
          attendanceRecords = records;
          isLoadingAttendance = false;
        });
      } else {
        _showError('Failed to load attendance');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _calculateStats(List<dynamic> records) {
    final newStats = {'Present': 0, 'Absent': 0, 'Late': 0, 'Excused': 0};

    for (var r in records) {
      final status = r['status'] as String;
      if (newStats.containsKey(status)) {
        newStats[status] = newStats[status]! + 1;
      }
    }

    final total = records.length;
    final present = newStats['Present']! + newStats['Late']!;
    final rate = total > 0 ? (present / total) * 100 : 0.0;

    // Calculate streaks
    int currentStreakCount = 0;
    int longestStreakCount = 0;
    int tempStreak = 0;

    // Sort records by date (newest first)
    final sortedRecords = List.from(records);
    sortedRecords.sort((a, b) {
      final dateA = DateTime.parse(a['session_date']);
      final dateB = DateTime.parse(b['session_date']);
      return dateB.compareTo(dateA);
    });

    for (int i = 0; i < sortedRecords.length; i++) {
      final status = sortedRecords[i]['status'];
      if (status == 'Present' || status == 'Late') {
        tempStreak++;
        if (i == 0) currentStreakCount = tempStreak;
        if (tempStreak > longestStreakCount) {
          longestStreakCount = tempStreak;
        }
      } else {
        if (i == 0) currentStreakCount = 0;
        tempStreak = 0;
      }
    }

    setState(() {
      stats = newStats;
      totalSessions = total;
      attendanceRate = rate;
      currentStreak = currentStreakCount;
      longestStreak = longestStreakCount;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final colors = {
      'Present': Colors.green,
      'Absent': Colors.red,
      'Late': Colors.orange,
      'Excused': Colors.blue,
    };

    return stats.entries.where((e) => e.value > 0).map((e) {
      final percentage =
          totalSessions > 0 ? (e.value / totalSessions) * 100 : 0;
      return PieChartSectionData(
        value: e.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        color: colors[e.key] ?? Colors.grey,
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: _buildBadge(e.key, colors[e.key]!),
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with Gradient
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade700,
                      Colors.blue.shade500,
                      Colors.purple.shade400,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white,
                              child:
                                  isLoadingProfile
                                      ? const CircularProgressIndicator()
                                      : Text(
                                        profile != null
                                            ? '${profile!['firstname'][0]}${profile!['surname'][0]}'
                                            : 'ST',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Welcome back,',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    profile != null
                                        ? '${profile!['firstname']} ${profile!['surname']}'
                                        : 'Student',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
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
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _loadProfile();
                  _loadEnrolledClasses();
                  if (selectedClassId != null) {
                    _selectClass(selectedClassId!, selectedClassName!);
                  }
                },
              ),
              LogoutButton(),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Class Selector with QR Button
                if (enrolledClasses.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedClassId,
                                isExpanded: true,
                                hint: const Text('Select a class'),
                                icon: const Icon(
                                  Icons.arrow_drop_down_circle_outlined,
                                ),
                                items:
                                    enrolledClasses.map((cls) {
                                      return DropdownMenuItem<String>(
                                        value: cls['id'].toString(),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.class_,
                                                color: Colors.blue.shade700,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    cls['name'],
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Grade ${cls['grade_level']} ${cls['section'] ?? ''}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  final cls = enrolledClasses.firstWhere(
                                    (c) => c['id'].toString() == value,
                                  );
                                  _selectClass(value, cls['name']);
                                },
                              ),
                            ),
                          ),
                        ),
                        if (selectedClassId != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade600,
                                  Colors.purple.shade500,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade200,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.qr_code_2,
                                color: Colors.white,
                                size: 28,
                              ),
                              tooltip: 'Show QR Code',
                              onPressed:
                                  () => _showQrCodeDialog(
                                    selectedClassId!,
                                    selectedClassName ?? 'Class',
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Statistics Cards
                if (selectedClassId != null) ...[
                  // Quick Stats Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Attendance Rate',
                            '${attendanceRate.toStringAsFixed(1)}%',
                            Icons.trending_up,
                            attendanceRate >= 80
                                ? Colors.green
                                : attendanceRate >= 60
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Classes',
                            '$totalSessions',
                            Icons.calendar_today,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Streak Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Current Streak',
                            '$currentStreak days',
                            Icons.local_fire_department,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Longest Streak',
                            '$longestStreak days',
                            Icons.emoji_events,
                            Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tabs
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.blue.shade700,
                      unselectedLabelColor: Colors.grey.shade600,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Records'),
                        Tab(text: 'Insights'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab Content
                  SizedBox(
                    height: 500,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildRecordsTab(),
                        _buildInsightsTab(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pie Chart Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Attendance Distribution',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 250,
                    child:
                        totalSessions == 0
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.pie_chart_outline,
                                    size: 64,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No attendance records yet',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : PieChart(
                              PieChartData(
                                sections: _buildPieSections(),
                                centerSpaceRadius: 0,
                                sectionsSpace: 2,
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {},
                                ),
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Status Breakdown
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Breakdown',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusRow('Present', stats['Present']!, Colors.green),
                  _buildStatusRow('Late', stats['Late']!, Colors.orange),
                  _buildStatusRow('Absent', stats['Absent']!, Colors.red),
                  _buildStatusRow('Excused', stats['Excused']!, Colors.blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, Color color) {
    final percentage = totalSessions > 0 ? (count / totalSessions) * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '$count (${percentage.toStringAsFixed(1)}%)',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTab() {
    return isLoadingAttendance
        ? const Center(child: CircularProgressIndicator())
        : attendanceRecords.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.list_alt, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No attendance records yet',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        )
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: attendanceRecords.length,
          itemBuilder: (context, i) {
            final r = attendanceRecords[i];
            final date = DateTime.parse(r['session_date']);
            final color = switch (r['status']) {
              'Present' => Colors.green,
              'Absent' => Colors.red,
              'Late' => Colors.orange,
              _ => Colors.blue,
            };

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(switch (r['status']) {
                    'Present' => Icons.check_circle,
                    'Absent' => Icons.cancel,
                    'Late' => Icons.access_time,
                    _ => Icons.info,
                  }, color: color),
                ),
                title: Text(DateFormat('EEEE, MMMM dd, yyyy').format(date)),
                subtitle: Text(
                  r['time_marked'] ?? 'Not marked',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    r['status'],
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          },
        );
  }

  Widget _buildInsightsTab() {
    // Calculate weekly attendance
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final recentRecords =
        attendanceRecords.where((r) {
          final date = DateTime.parse(r['session_date']);
          return date.isAfter(weekAgo);
        }).toList();

    final weeklyPresent =
        recentRecords
            .where((r) => r['status'] == 'Present' || r['status'] == 'Late')
            .length;
    final weeklyTotal = recentRecords.length;
    final weeklyRate =
        weeklyTotal > 0 ? (weeklyPresent / weeklyTotal) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Weekly Performance
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.insights, color: Colors.purple.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Weekly Performance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInsightRow(
                    'This Week',
                    '$weeklyPresent/$weeklyTotal classes',
                    weeklyRate >= 80 ? Icons.trending_up : Icons.trending_down,
                    weeklyRate >= 80 ? Colors.green : Colors.red,
                  ),
                  const Divider(height: 24),
                  _buildInsightRow(
                    'Overall',
                    '${attendanceRate.toStringAsFixed(1)}%',
                    Icons.analytics,
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Performance Badge
          if (attendanceRate >= 95)
            Card(
              elevation: 2,
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.amber.shade700,
                      size: 48,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Excellent Attendance!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Keep up the great work! 🎉',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (attendanceRate < 75)
            Card(
              elevation: 2,
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade700,
                      size: 48,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Needs Improvement',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Try to attend more classes regularly',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
