import 'dart:convert';
import 'package:attsys/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'student_profile.dart';

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
  String? errorMessage;

  final TextEditingController _lrnController = TextEditingController();

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
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

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
          students = json.decode(res.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load students (${res.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _addStudent() async {
    final lrn = _lrnController.text.trim();
    if (lrn.isEmpty || lrn.length != 12 || !RegExp(r'^\d{12}$').hasMatch(lrn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 12-digit LRN'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final token = await _getToken();
      final res = await http
          .post(
            Uri.parse(ApiConfig.teacherClassStudents(widget.classId)),
            headers: ApiConfig.headers(token),
            body: json.encode({'lrn': lrn}),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 201) {
        final data = json.decode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${data['studentName']} added to class'),
            backgroundColor: Colors.green,
          ),
        );
        _lrnController.clear();
        _loadStudents();
      } else {
        final err = json.decode(res.body)['message'] ?? 'Failed to add';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [BackButton()],
        backgroundColor: Colors.transparent,
      ),
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
              // Custom header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Class Students',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.className,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Refresh',
                      onPressed: _loadStudents,
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadStudents,
                  color: const Color(0xFF667eea),
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Add student card
                          Container(
                            padding: const EdgeInsets.all(20),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Add Student',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _lrnController,
                                        decoration: InputDecoration(
                                          labelText: 'Enter 12-digit LRN',
                                          prefixIcon: const Icon(
                                            Icons.badge_rounded,
                                            color: Color(0xFF667eea),
                                          ),
                                          suffixIcon:
                                              _lrnController.text.isNotEmpty
                                                  ? IconButton(
                                                    icon: const Icon(
                                                      Icons.clear_rounded,
                                                    ),
                                                    onPressed: () {
                                                      _lrnController.clear();
                                                      setState(() {});
                                                    },
                                                  )
                                                  : null,
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF667eea),
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 16,
                                                horizontal: 20,
                                              ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        maxLength: 12,
                                        onChanged: (value) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton(
                                      onPressed:
                                          _lrnController.text.length == 12
                                              ? _addStudent
                                              : null,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                        backgroundColor: const Color(
                                          0xFF4CAF50,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.person_add_rounded,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Add'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Students list card
                          Container(
                            padding: const EdgeInsets.all(20),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Enrolled Students',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${students.length} student${students.length != 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (isLoading)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF667eea),
                                    ),
                                  )
                                else if (errorMessage != null)
                                  Center(
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          size: 64,
                                          color: Colors.redAccent,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          errorMessage!,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        OutlinedButton.icon(
                                          onPressed: _loadStudents,
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                          ),
                                          label: const Text('Retry'),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: Color(0xFF667eea),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (students.isEmpty)
                                  Center(
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.people_outline_rounded,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No students enrolled yet',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add students using their LRN above',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: students.length,
                                    itemBuilder: (context, index) {
                                      final s = students[index];
                                      final name =
                                          s['full_name'] ??
                                          '${s['firstname']} ${s['suffix'] ?? ''} ${s['surname']}'
                                              .trim();
                                      final initials =
                                          '${s['firstname'][0]}${s['surname'][0]}'
                                              .toUpperCase();

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: const Color(
                                                0xFF667eea,
                                              ).withOpacity(0.1),
                                              child: Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: Color(0xFF667eea),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'LRN: ${s['lrn']}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                                if (s['birthday'] != null)
                                                  Text(
                                                    'Birthday: ${s['birthday']}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Colors.grey,
                                            ),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          StudentProfileScreen(
                                                            lrn: s['lrn'],
                                                            classId:
                                                                widget.classId,
                                                          ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  @override
  void dispose() {
    _lrnController.dispose();
    super.dispose();
  }
}
