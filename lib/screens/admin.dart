import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<dynamic> teachers = [];
  String? selectedTeacherId;
  String? selectedTeacherName;
  List<dynamic> teacherClasses = [];
  bool loadingTeachers = true;
  bool loadingClasses = false;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllTeachers();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadAllTeachers() async {
    setState(() => loadingTeachers = true);

    try {
      final token = await _getToken();
      final res = await http
          .get(
            Uri.parse(ApiConfig.adminTeachers),
            headers: ApiConfig.headers(token),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        setState(() {
          teachers = json.decode(res.body);
          loadingTeachers = false;
        });
      } else {
        setState(() => loadingTeachers = false);
      }
    } catch (e) {
      setState(() => loadingTeachers = false);
    }
  }

  Future<void> _loadTeacherClasses(String teacherId) async {
    setState(() {
      loadingClasses = true;
      teacherClasses = [];
      selectedTeacherId = teacherId;

      final teacher = teachers.firstWhere(
        (t) => t['id'].toString() == teacherId,
        orElse: () => {},
      );
      selectedTeacherName =
          teacher['name'] ??
          '${teacher['firstname'] ?? ''} ${teacher['surname'] ?? ''}'.trim();
    });

    try {
      final token = await _getToken();
      final res = await http
          .get(
            Uri.parse(ApiConfig.adminTeacherClasses(teacherId)),
            headers: ApiConfig.headers(token),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        setState(() {
          teacherClasses = json.decode(res.body);
          loadingClasses = false;
        });
      } else {
        setState(() => loadingClasses = false);
      }
    } catch (e) {
      setState(() => loadingClasses = false);
    }
  }

  Future<void> _createClassForTeacher() async {
    if (selectedTeacherId == null) {
      return;
    }

    final nameController = TextEditingController();
    final sectionController = TextEditingController();
    final gradeController = TextEditingController();
    final schoolYearController = TextEditingController(text: '2025-2026');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: Text(
              'Add New Class for $selectedTeacherName',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Class Name *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: gradeController,
                    decoration: InputDecoration(
                      labelText: 'Grade Level *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sectionController,
                    decoration: InputDecoration(
                      labelText: 'Section (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: schoolYearController,
                    decoration: InputDecoration(
                      labelText: 'School Year *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final grade = gradeController.text.trim();

                  if (name.isEmpty || grade.isEmpty) {
                    return;
                  }

                  try {
                    final token = await _getToken();
                    final res = await http
                        .post(
                          Uri.parse(
                            ApiConfig.adminTeacherClasses(selectedTeacherId!),
                          ),
                          headers: ApiConfig.headers(token),
                          body: json.encode({
                            'name': name,
                            'gradeLevel': grade,
                            'section':
                                sectionController.text.trim().isEmpty
                                    ? null
                                    : sectionController.text.trim(),
                            'schoolYear': schoolYearController.text.trim(),
                          }),
                        )
                        .timeout(ApiConfig.timeout);

                    if (res.statusCode == 201) {
                      Navigator.pop(context);
                      _loadTeacherClasses(selectedTeacherId!);
                    } else {
                      final msg = json.decode(res.body)['message'] ?? 'Failed';
                    }
                  } catch (e) {}
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteClass(String classId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: const Text('Confirm Delete'),
            content: const Text(
              'Delete this class and all related attendance records? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true || selectedTeacherId == null) return;

    try {
      final token = await _getToken();
      final res = await http
          .delete(
            Uri.parse(ApiConfig.adminDeleteClass(classId)),
            headers: ApiConfig.headers(token),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200 || res.statusCode == 204) {
        _loadTeacherClasses(selectedTeacherId!);
      } else {}
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isSmallScreen = width < 720;

    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    );

    return Scaffold(
      extendBodyBehindAppBar: isSmallScreen,
      drawer: null,
      appBar:
          isSmallScreen
              ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: Container(
                  decoration: BoxDecoration(gradient: gradient),
                ),
                title: Text(
                  'Admin Dashboard',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black45,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
                leading:
                    selectedTeacherId == null
                        ? null
                        : IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed:
                              () => setState(() => selectedTeacherId = null),
                        ),
              )
              : null,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child:
              isSmallScreen
                  ? _buildMobileLayout()
                  : _buildDesktopTabletLayout(width),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        if (selectedTeacherId == null)
          Expanded(child: _buildTeacherList())
        else
          Expanded(child: _buildClassesPanel()),
      ],
    );
  }

  Widget _buildDesktopTabletLayout(double width) {
    final isMedium = width < 1100;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: isMedium ? 320 : 380, child: _buildTeacherList()),
        Expanded(child: _buildClassesPanel()),
      ],
    );
  }

  Widget _buildTeacherList() {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  Icons.school_rounded,
                  color: Color(0xFF667eea),
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Teachers',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${teachers.length}',
                    style: const TextStyle(
                      color: Color(0xFF667eea),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search teachers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                loadingTeachers
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF667eea),
                      ),
                    )
                    : teachers.isEmpty
                    ? const Center(
                      child: Text(
                        'No teachers found',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                    : () {
                      final filteredTeachers =
                          searchQuery.isEmpty
                              ? teachers
                              : teachers.where((teacher) {
                                final name =
                                    teacher['name'] ??
                                    '${teacher['firstname'] ?? ''} ${teacher['surname'] ?? ''}'
                                        .trim();
                                return name.toLowerCase().contains(
                                  searchQuery.toLowerCase(),
                                );
                              }).toList();

                      if (filteredTeachers.isEmpty) {
                        return const Center(
                          child: Text(
                            'No teachers match the search',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filteredTeachers.length,
                        itemBuilder: (context, index) {
                          final teacher = filteredTeachers[index];
                          final isSelected =
                              selectedTeacherId == teacher['id'].toString();
                          final name =
                              teacher['name'] ??
                              '${teacher['firstname'] ?? ''} ${teacher['surname'] ?? ''}'
                                  .trim();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(
                                          0xFF667eea,
                                        ).withOpacity(0.1)
                                        : null,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      isSelected
                                          ? const Color(0xFF667eea)
                                          : Colors.grey.shade300,
                                  child: Icon(
                                    Icons.person_rounded,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                  ),
                                ),
                                title: Text(
                                  name.isEmpty ? 'Unknown' : name,
                                  style: TextStyle(
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  '${teacher['classes_count'] ?? 0} classes • ID: ${teacher['id']}',
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? const Color(0xFF667eea)
                                            : Colors.grey.shade700,
                                  ),
                                ),
                                onTap: () {
                                  _loadTeacherClasses(teacher['id'].toString());
                                },
                              ),
                            ),
                          );
                        },
                      );
                    }(),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesPanel() {
    if (selectedTeacherId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.arrow_forward_rounded,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            const Text(
              'Select a teacher\nto view their classes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Classes',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  Text(
                    selectedTeacherName ?? 'Teacher',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('New Class'),
                onPressed: _createClassForTeacher,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              loadingClasses
                  ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF667eea)),
                  )
                  : teacherClasses.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.class_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No classes assigned yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: teacherClasses.length,
                    itemBuilder: (context, index) {
                      final cls = teacherClasses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF667eea),
                                    Color(0xFF764ba2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.class_rounded,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              cls['name'] ?? 'Unnamed',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Grade ${cls['grade_level']}${cls['section'] != null ? ' - ${cls['section']}' : ''}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                Text(
                                  'SY: ${cls['school_year']} • ${cls['student_count'] ?? 0} students',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed:
                                      () => _deleteClass(cls['id'].toString()),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
