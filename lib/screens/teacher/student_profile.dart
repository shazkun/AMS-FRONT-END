import 'dart:convert';
import 'package:attsys/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentProfileScreen extends StatefulWidget {
  final String? lrn; // null = own profile, non-null = viewing specific student
  final String? classId; // Required for QR generation

  const StudentProfileScreen({super.key, this.lrn, this.classId});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? errorMessage;
  String? qrPayload;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      String url;
      if (widget.lrn != null) {
        // Teacher viewing specific student
        url = ApiConfig.teacherStudents(widget.lrn!);
      } else {
        // Own profile
        url = ApiConfig.studentProfile;
      }

      final res = await http
          .get(Uri.parse(url), headers: ApiConfig.headers(token))
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          profile = data;
          isLoading = false;
        });
        _generateQrPayload();
      } else {
        setState(() {
          errorMessage =
              'Failed to load profile: ${res.statusCode} - ${res.body}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  void _generateQrPayload() {
    if (profile == null || profile!['lrn'] == null) {
      debugPrint("QR generation skipped: no LRN");
      return;
    }

    // ✅ FIXED: Generate correct payload format
    final classId = widget.classId ?? "1"; // Use provided or default
    final lrn = profile!['lrn'];
    final surname = profile!['surname'];
    final firstname = profile!['firstname'];

    setState(() {
      qrPayload = '$surname,$firstname |lrn:$lrn|class:$classId';
      debugPrint("QR generated: $qrPayload");
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.lrn == null;
    final title = isOwnProfile ? 'My Profile' : 'Student Profile';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadProfile,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : profile == null
              ? const Center(child: Text('No profile data'))
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.blue.shade700, Colors.blue.shade500],
                        ),
                      ),
                      child: Column(
                        children: [
                          Hero(
                            tag: 'avatar_${profile!['lrn']}',
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.white,
                              child: Text(
                                '${profile!['firstname'][0]}${profile!['surname'][0]}'
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 48,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${profile!['firstname']} ${profile!['suffix'] ?? ''} ${profile!['surname']}'
                                .trim(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'LRN: ${profile!['lrn']}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Profile Details Card
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
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
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                Icons.cake,
                                'Birthday',
                                profile!['birthday'] ?? '—',
                              ),
                              const Divider(height: 24),
                              _buildInfoRow(
                                Icons.badge,
                                'Full Name',
                                '${profile!['firstname']} ${profile!['suffix'] ?? ''} ${profile!['surname']}'
                                    .trim(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // QR Code Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_2,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.lrn == null
                                        ? 'Your Attendance QR Code'
                                        : 'Student QR Code',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              if (qrPayload == null)
                                SizedBox(
                                  height: 260,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 48,
                                          color: Colors.orange.shade300,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'QR Code Not Available',
                                          style: TextStyle(
                                            color: Colors.orange.shade800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Class ID required',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: QrImageView(
                                    data: qrPayload!,
                                    version: QrVersions.auto,
                                    size: 240,
                                    backgroundColor: Colors.white,
                                    eyeStyle: QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Colors.blue.shade900,
                                    ),
                                    dataModuleStyle: QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.circle,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 16),

                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.lrn == null
                                            ? 'Show this QR code to your teacher to mark your attendance'
                                            : 'Scan this QR code to mark student attendance',
                                        style: TextStyle(
                                          color: Colors.blue.shade900,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (qrPayload != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Format: $qrPayload',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.blue.shade700),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
