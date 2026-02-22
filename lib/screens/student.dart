import 'dart:convert';
import 'package:attsys/widgets/logout.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme constants
// ─────────────────────────────────────────────────────────────────────────────
const _kBreakpoint = 720.0;

const _kGrad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
);
const _kAccent = Color(0xFF0EA5E9);
const _kIndigo = Color(0xFF6366F1);
const _kBg = Color(0xFFF1F5F9);
const _kCard = Colors.white;

// ─────────────────────────────────────────────────────────────────────────────
// Avatar model
// ─────────────────────────────────────────────────────────────────────────────
enum AvatarType { initials, emoji }

class StudentAvatar {
  final AvatarType type;
  final String value;
  const StudentAvatar({required this.type, required this.value});
}

const List<String> kAvatarEmojis = [
  '😊',
  '🎓',
  '📚',
  '🌟',
  '🦁',
  '🐯',
  '🦊',
  '🐼',
  '🐸',
  '🦄',
  '🐲',
  '🦋',
  '🌈',
  '⭐',
  '🔥',
  '🎯',
  '🏆',
  '💡',
  '🚀',
  '🎨',
  '🎵',
  '⚽',
  '🏀',
  '🎮',
];

// ─────────────────────────────────────────────────────────────────────────────
// Edit Profile Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _EditProfileDialog({required this.profile, required this.onSave});
  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _suffixCtrl;
  String? _sex;
  DateTime? _birthday;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.profile['firstname'] ?? '');
    _lastCtrl = TextEditingController(text: widget.profile['surname'] ?? '');
    _suffixCtrl = TextEditingController(text: widget.profile['suffix'] ?? '');
    _sex = widget.profile['sex'] as String?;
    final bd = widget.profile['birthday'] as String?;
    if (bd != null && bd.isNotEmpty) {
      try {
        _birthday = DateTime.parse(bd);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _suffixCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 12),
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year - 4),
      builder:
          (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: _kAccent,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
    );
    if (d != null) setState(() => _birthday = d);
  }

  Future<void> _submit() async {
    final fn = _firstCtrl.text.trim();
    final sn = _lastCtrl.text.trim();
    if (fn.isEmpty) {
      setState(() => _error = 'First name is required');
      return;
    }
    if (sn.isEmpty) {
      setState(() => _error = 'Surname is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave({
        'firstname': fn,
        'surname': sn,
        'suffix':
            _suffixCtrl.text.trim().isEmpty ? null : _suffixCtrl.text.trim(),
        'birthday':
            _birthday != null
                ? DateFormat('yyyy-MM-dd').format(_birthday!)
                : null,
        'sex': _sex,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  InputDecoration _fd(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    prefixIcon: icon != null ? Icon(icon, color: _kAccent, size: 18) : null,
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
      borderSide: const BorderSide(color: _kAccent, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
    isDense: true,
  );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: w < 600 ? 16 : 80,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: _kGrad,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Update your personal information',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_rounded, color: _kAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'LRN: ${widget.profile['lrn']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _kAccent,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'cannot be changed',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstCtrl,
                            decoration: _fd(
                              'First Name',
                              icon: Icons.person_outline,
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lastCtrl,
                            decoration: _fd(
                              'Surname',
                              icon: Icons.person_outline,
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _suffixCtrl,
                            decoration: _fd('Suffix (optional)'),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _sex,
                            decoration: _fd('Sex', icon: Icons.wc_rounded),
                            items: const [
                              DropdownMenuItem(
                                value: 'Male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'Female',
                                child: Text('Female'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _sex = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                _birthday != null
                                    ? _kAccent
                                    : Colors.grey.shade200,
                            width: _birthday != null ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cake_rounded,
                              color: _kAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _birthday != null
                                    ? DateFormat(
                                      'MMMM d, yyyy',
                                    ).format(_birthday!)
                                    : 'Birthday (optional)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      _birthday != null
                                          ? Colors.black87
                                          : Colors.grey.shade500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
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
                              size: 16,
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon:
                        _saving
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_saving ? 'Saving…' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Root widget — layout switch
// ─────────────────────────────────────────────────────────────────────────────
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
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

  StudentAvatar _avatar = const StudentAvatar(
    type: AvatarType.initials,
    value: 'ST',
  );
  static const String _avatarKey = 'student_avatar_type';
  static const String _avatarValueKey = 'student_avatar_value';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAvatar();
    _loadProfile();
    _loadEnrolledClasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────
  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString(_avatarKey);
    final value = prefs.getString(_avatarValueKey);
    if (type != null && value != null) {
      setState(
        () =>
            _avatar = StudentAvatar(
              type: type == 'emoji' ? AvatarType.emoji : AvatarType.initials,
              value: value,
            ),
      );
    }
  }

  Future<void> _saveAvatar(StudentAvatar avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _avatarKey,
      avatar.type == AvatarType.emoji ? 'emoji' : 'initials',
    );
    await prefs.setString(_avatarValueKey, avatar.value);
    setState(() => _avatar = avatar);
  }

  String _getInitials() {
    if (profile == null) return 'ST';
    final f = profile!['firstname'] as String? ?? '';
    final l = profile!['surname'] as String? ?? '';
    if (f.isEmpty && l.isEmpty) return 'ST';
    return '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'
        .toUpperCase();
  }

  void _showAvatarPicker() {
    final initials = _getInitials();
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose Your Avatar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _saveAvatar(
                        StudentAvatar(
                          type: AvatarType.initials,
                          value: initials,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _avatar.type == AvatarType.initials
                                ? Colors.blue.shade50
                                : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              _avatar.type == AvatarType.initials
                                  ? Colors.blue.shade400
                                  : Colors.grey.shade200,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: _kAccent,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Use Initials',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Classic look with your name initials',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_avatar.type == AvatarType.initials)
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.blue.shade600,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose an Emoji',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: kAvatarEmojis.length,
                    itemBuilder: (context, i) {
                      final emoji = kAvatarEmojis[i];
                      final isSelected =
                          _avatar.type == AvatarType.emoji &&
                          _avatar.value == emoji;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _saveAvatar(
                            StudentAvatar(type: AvatarType.emoji, value: emoji),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Colors.blue.shade50
                                    : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.blue.shade400
                                      : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildAvatar({double radius = 28}) {
    return GestureDetector(
      onTap: _showAvatarPicker,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white,
            child:
                _avatar.type == AvatarType.emoji
                    ? Text(
                      _avatar.value,
                      style: TextStyle(fontSize: radius * 0.9),
                    )
                    : Text(
                      _getInitials(),
                      style: TextStyle(
                        fontSize: radius * 0.7,
                        fontWeight: FontWeight.bold,
                        color: _kAccent,
                      ),
                    ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _kAccent,
                shape: BoxShape.circle,
                border: const Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ── Data ───────────────────────────────────────────────────────────────────
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
          if (_avatar.type == AvatarType.initials)
            _avatar = StudentAvatar(
              type: AvatarType.initials,
              value: _getInitials(),
            );
        });
      } else {
        setState(() => isLoadingProfile = false);
      }
    } catch (_) {
      setState(() => isLoadingProfile = false);
    }
  }

  Future<void> _saveProfile(Map<String, dynamic> data) async {
    final token = await _getToken();
    final res = await http
        .put(
          Uri.parse(ApiConfig.studentUpdateProfile),
          headers: ApiConfig.headers(token),
          body: json.encode(data),
        )
        .timeout(ApiConfig.timeout);
    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      setState(() {
        profile = body['profile'] ?? profile;
        if (_avatar.type == AvatarType.initials)
          _avatar = StudentAvatar(
            type: AvatarType.initials,
            value: _getInitials(),
          );
      });
    } else {
      final msg =
          json.decode(res.body)['message'] ?? 'Failed to update profile';
      throw Exception(msg);
    }
  }

  Future<void> _openEditProfile() async {
    if (profile == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => _EditProfileDialog(profile: profile!, onSave: _saveProfile),
    );
    if (result == true) _showSnack('Profile updated successfully ✓');
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
        final data = json.decode(res.body) as List;
        setState(() {
          enrolledClasses = data;
          isLoadingClasses = false;
        });
        if (data.isNotEmpty)
          _selectClass(data[0]['id'].toString(), data[0]['name']);
      } else {
        setState(() => isLoadingClasses = false);
      }
    } catch (_) {
      setState(() => isLoadingClasses = false);
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
        setState(() => isLoadingAttendance = false);
      }
    } catch (_) {
      setState(() => isLoadingAttendance = false);
    }
  }

  void _calculateStats(List<dynamic> records) {
    final s = {'Present': 0, 'Absent': 0, 'Late': 0, 'Excused': 0};
    for (var r in records) {
      final status = r['status'] as String;
      if (s.containsKey(status)) s[status] = s[status]! + 1;
    }
    final total = records.length;
    final present = s['Present']! + s['Late']!;
    final rate = total > 0 ? (present / total) * 100 : 0.0;

    int cs = 0, ls = 0, tmp = 0;
    final sorted = List.from(records)..sort(
      (a, b) => DateTime.parse(
        b['session_date'],
      ).compareTo(DateTime.parse(a['session_date'])),
    );
    for (int i = 0; i < sorted.length; i++) {
      final st = sorted[i]['status'];
      if (st == 'Present' || st == 'Late') {
        tmp++;
        if (i == 0) cs = tmp;
        if (tmp > ls) ls = tmp;
      } else {
        if (i == 0) cs = 0;
        tmp = 0;
      }
    }
    setState(() {
      stats = s;
      totalSessions = total;
      attendanceRate = rate;
      currentStreak = cs;
      longestStreak = ls;
    });
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _generateQrPayload(String classId) {
    if (profile == null) return '';
    return '${profile!['surname']},${profile!['firstname']}|lrn:${profile!['lrn']}|class:$classId';
  }

  void _showQrDialog(String classId, String className) {
    final payload = _generateQrPayload(classId);
    if (payload.isEmpty) {
      _showSnack('Unable to generate QR code', success: false);
      return;
    }
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
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
                        color: _kAccent,
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile!['firstname']} ${profile!['suffix'] ?? ''} ${profile!['surname']}'
                          .trim(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'LRN: ${profile!['lrn']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
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
                        data: payload,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: _kAccent,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: const Color(0xFF0C4A6E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.green.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Show this QR to your teacher to mark attendance',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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

  void _refreshAll() {
    _loadProfile();
    _loadEnrolledClasses();
    if (selectedClassId != null)
      _selectClass(selectedClassId!, selectedClassName!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
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
          // ── Left Rail ──────────────────────────────────────────────────────
          Container(
            width: 260,
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
                  // Header / avatar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildAvatar(radius: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Student',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const Text(
                                    'Dashboard',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (isLoadingProfile)
                          const LinearProgressIndicator(
                            color: Colors.white70,
                            backgroundColor: Colors.white24,
                          )
                        else if (profile != null) ...[
                          Text(
                            '${profile!['firstname']} ${profile!['surname']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'LRN: ${profile!['lrn']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _RailStat(
                          icon: Icons.class_rounded,
                          label: 'Enrolled Classes',
                          value: '${enrolledClasses.length}',
                          loading: isLoadingClasses,
                        ),
                        const SizedBox(height: 6),
                        _RailStat(
                          icon: Icons.trending_up_rounded,
                          label: 'Attendance Rate',
                          value: '${attendanceRate.toStringAsFixed(1)}%',
                          loading: isLoadingAttendance,
                          valueColor:
                              attendanceRate >= 80
                                  ? Colors.greenAccent.shade200
                                  : attendanceRate >= 60
                                  ? Colors.orangeAccent.shade200
                                  : Colors.redAccent.shade200,
                        ),
                        const SizedBox(height: 6),
                        _RailStat(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Current Streak',
                          value: '$currentStreak days',
                          loading: isLoadingAttendance,
                          valueColor: Colors.orangeAccent.shade200,
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

                  // Class list title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'MY CLASSES',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  // Class nav items
                  Expanded(
                    child:
                        isLoadingClasses
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white70,
                                strokeWidth: 2,
                              ),
                            )
                            : enrolledClasses.isEmpty
                            ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Not enrolled in any class yet.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: enrolledClasses.length,
                              itemBuilder: (_, i) {
                                final cls = enrolledClasses[i];
                                final cid = cls['id'].toString();
                                final isSelected = cid == selectedClassId;
                                return _DesktopClassNavItem(
                                  cls: cls,
                                  isSelected: isSelected,
                                  onTap: () => _selectClass(cid, cls['name']),
                                );
                              },
                            ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Column(
                      children: [
                        if (profile != null)
                          _RailAction(
                            icon: Icons.edit_rounded,
                            label: 'Edit Profile',
                            onTap: _openEditProfile,
                            highlight: true,
                          ),
                        const SizedBox(height: 6),
                        _RailAction(
                          icon: Icons.refresh_rounded,
                          label: 'Refresh',
                          onTap: _refreshAll,
                        ),
                        const SizedBox(height: 6),
                        const _RailLogout(),
                      ],
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
                // Top bar
                Container(
                  height: 60,
                  color: _kCard,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedClassName ?? 'Select a Class',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (selectedClassId != null)
                              Text(
                                'Attendance Records',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (selectedClassId != null) ...[
                        // QR button
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          child: ElevatedButton.icon(
                            onPressed:
                                () => _showQrDialog(
                                  selectedClassId!,
                                  selectedClassName!,
                                ),
                            icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                            label: const Text(
                              'My QR Code',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        // Attendance rate badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                attendanceRate >= 80
                                    ? Colors.green.shade50
                                    : attendanceRate >= 60
                                    ? Colors.orange.shade50
                                    : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  attendanceRate >= 80
                                      ? Colors.green.shade200
                                      : attendanceRate >= 60
                                      ? Colors.orange.shade200
                                      : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_up_rounded,
                                size: 14,
                                color:
                                    attendanceRate >= 80
                                        ? Colors.green
                                        : attendanceRate >= 60
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${attendanceRate.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color:
                                      attendanceRate >= 80
                                          ? Colors.green.shade700
                                          : attendanceRate >= 60
                                          ? Colors.orange.shade700
                                          : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Main content
                Expanded(
                  child:
                      selectedClassId == null
                          ? _buildDesktopEmptyState()
                          : isLoadingAttendance
                          ? const Center(
                            child: CircularProgressIndicator(color: _kAccent),
                          )
                          : _buildDesktopContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, size: 60, color: _kAccent),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select a class from the sidebar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your attendance records will appear here',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stats sidebar ─────────────────────────────────────────────────
        Container(
          width: 220,
          color: _kCard,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STATS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade400,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _DesktopStatCard(
                label: 'Total Sessions',
                value: '$totalSessions',
                icon: Icons.calendar_today_rounded,
                color: Colors.blue,
              ),
              const SizedBox(height: 8),
              _DesktopStatCard(
                label: 'Present',
                value: '${stats['Present']}',
                icon: Icons.check_circle_rounded,
                color: Colors.green,
              ),
              const SizedBox(height: 8),
              _DesktopStatCard(
                label: 'Absent',
                value: '${stats['Absent']}',
                icon: Icons.cancel_rounded,
                color: Colors.red,
              ),
              const SizedBox(height: 8),
              _DesktopStatCard(
                label: 'Late',
                value: '${stats['Late']}',
                icon: Icons.access_time_rounded,
                color: Colors.orange,
              ),
              const SizedBox(height: 8),
              _DesktopStatCard(
                label: 'Excused',
                value: '${stats['Excused']}',
                icon: Icons.info_rounded,
                color: Colors.indigo,
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'STREAKS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade400,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _DesktopStatCard(
                label: 'Current Streak',
                value: '$currentStreak d',
                icon: Icons.local_fire_department_rounded,
                color: Colors.orange,
              ),
              const SizedBox(height: 8),
              _DesktopStatCard(
                label: 'Longest Streak',
                value: '$longestStreak d',
                icon: Icons.emoji_events_rounded,
                color: Colors.amber,
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),

        // ── Tabs content ─────────────────────────────────────────────────
        Expanded(
          child: Column(
            children: [
              Container(
                color: _kCard,
                child: TabBar(
                  controller: _tabController,
                  labelColor: _kAccent,
                  unselectedLabelColor: Colors.grey.shade500,
                  indicatorColor: _kAccent,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Records'),
                    Tab(text: 'Insights'),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
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
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: _kGrad),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            _buildAvatar(radius: 30),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Welcome back,',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    isLoadingProfile
                                        ? 'Loading…'
                                        : profile != null
                                        ? '${profile!['firstname']} ${profile!['surname']}'
                                        : 'Student',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (profile != null) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'LRN: ${profile!['lrn']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
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
                            _MobileChip(
                              icon: Icons.class_rounded,
                              label: '${enrolledClasses.length} classes',
                              loading: isLoadingClasses,
                            ),
                            _MobileChip(
                              icon: Icons.trending_up_rounded,
                              label:
                                  '${attendanceRate.toStringAsFixed(0)}% rate',
                              loading: isLoadingAttendance,
                            ),
                            _MobileChip(
                              icon: Icons.local_fire_department_rounded,
                              label: '$currentStreak day streak',
                              loading: isLoadingAttendance,
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
                icon: const Icon(Icons.edit_rounded),
                onPressed: _openEditProfile,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshAll,
              ),
              const LogoutButton(),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // Not enrolled
                if (!isLoadingClasses && enrolledClasses.isEmpty)
                  _buildMobileNotEnrolled(),

                // Class selector
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
                                    enrolledClasses
                                        .map(
                                          (cls) => DropdownMenuItem<String>(
                                            value: cls['id'].toString(),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    7,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.class_,
                                                    color: _kAccent,
                                                    size: 18,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        cls['name'],
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Grade ${cls['grade_level']} ${cls['section'] ?? ''}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  final cls = enrolledClasses.firstWhere(
                                    (c) => c['id'].toString() == v,
                                  );
                                  _selectClass(v, cls['name']);
                                },
                              ),
                            ),
                          ),
                        ),
                        if (selectedClassId != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: _kGrad,
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.qr_code_2,
                                color: Colors.white,
                                size: 26,
                              ),
                              onPressed:
                                  () => _showQrDialog(
                                    selectedClassId!,
                                    selectedClassName!,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Stat row
                if (selectedClassId != null)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        _MobileStatPill(
                          label: 'Present',
                          value: '${stats['Present']}',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _MobileStatPill(
                          label: 'Absent',
                          value: '${stats['Absent']}',
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        _MobileStatPill(
                          label: 'Late',
                          value: '${stats['Late']}',
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _MobileStatPill(
                          label: 'Excused',
                          value: '${stats['Excused']}',
                          color: Colors.indigo,
                        ),
                        const SizedBox(width: 8),
                        _MobileStatPill(
                          label: 'Total',
                          value: '$totalSessions',
                          color: Colors.blueGrey,
                        ),
                      ],
                    ),
                  ),

                // Tabs
                if (selectedClassId != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: _kAccent,
                      unselectedLabelColor: Colors.grey.shade600,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Records'),
                        Tab(text: 'Insights'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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

  Widget _buildMobileNotEnrolled() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 48, color: Colors.amber.shade700),
          const SizedBox(height: 12),
          Text(
            'Not Enrolled in Any Class',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask your teacher to add you using your LRN.',
            style: TextStyle(fontSize: 13, color: Colors.amber.shade800),
            textAlign: TextAlign.center,
          ),
          if (profile != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'LRN: ${profile!['lrn']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared tab content
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 240,
                    child:
                        totalSessions == 0
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.pie_chart_outline,
                                    size: 60,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No records yet',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
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
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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

  List<PieChartSectionData> _buildPieSections() {
    final colors = {
      'Present': Colors.green,
      'Absent': Colors.red,
      'Late': Colors.orange,
      'Excused': Colors.blue,
    };
    return stats.entries.where((e) => e.value > 0).map((e) {
      final pct = totalSessions > 0 ? (e.value / totalSessions) * 100 : 0.0;
      return PieChartSectionData(
        value: e.value.toDouble(),
        title: '${pct.toStringAsFixed(1)}%',
        color: colors[e.key] ?? Colors.grey,
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: _buildBadge(e.key, colors[e.key]!),
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  Widget _buildBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildStatusRow(String label, int count, Color color) {
    final pct = totalSessions > 0 ? (count / totalSessions) * 100 : 0.0;
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
            '$count (${pct.toStringAsFixed(1)}%)',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTab() {
    if (isLoadingAttendance)
      return const Center(child: CircularProgressIndicator());
    if (attendanceRecords.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No attendance records yet',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: attendanceRecords.length,
      itemBuilder: (ctx, i) {
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
            title: Text(DateFormat('EEE, MMM dd, yyyy').format(date)),
            subtitle: Text(
              r['time_marked'] ?? 'Not marked',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final recent =
        attendanceRecords
            .where((r) => DateTime.parse(r['session_date']).isAfter(weekAgo))
            .toList();
    final weekPresent =
        recent
            .where((r) => r['status'] == 'Present' || r['status'] == 'Late')
            .length;
    final weekTotal = recent.length;
    final weekRate = weekTotal > 0 ? (weekPresent / weekTotal) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                      Icon(Icons.insights, color: _kIndigo),
                      const SizedBox(width: 8),
                      const Text(
                        'Weekly Performance',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInsightRow(
                    'This Week',
                    '$weekPresent/$weekTotal classes',
                    weekRate >= 80 ? Icons.trending_up : Icons.trending_down,
                    weekRate >= 80 ? Colors.green : Colors.red,
                  ),
                  const Divider(height: 24),
                  _buildInsightRow(
                    'Overall Rate',
                    '${attendanceRate.toStringAsFixed(1)}%',
                    Icons.analytics,
                    Colors.blue,
                  ),
                  const Divider(height: 24),
                  _buildInsightRow(
                    'Longest Streak',
                    '$longestStreak days',
                    Icons.emoji_events,
                    Colors.amber,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Excellent Attendance!',
                            style: TextStyle(
                              fontSize: 17,
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
          else if (attendanceRate < 75 && totalSessions > 0)
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
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Needs Improvement',
                            style: TextStyle(
                              fontSize: 17,
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
  ) => Row(
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Desktop sub-widgets
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
                fontSize: 13,
              ),
            ),
      ],
    ),
  );
}

class _DesktopClassNavItem extends StatelessWidget {
  final Map<String, dynamic> cls;
  final bool isSelected;
  final VoidCallback onTap;
  const _DesktopClassNavItem({
    required this.cls,
    required this.isSelected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            isSelected
                ? Colors.white.withOpacity(0.22)
                : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected
                ? Border.all(color: Colors.white.withOpacity(0.4))
                : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.class_rounded,
              size: 16,
              color: isSelected ? _kAccent : Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls['name'] ?? '—',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Grade ${cls['grade_level']} ${cls['section'] ?? ''}',
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ),
          if (isSelected)
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    ),
  );
}

class _DesktopStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _DesktopStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => InkWell(
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
            highlight ? Border.all(color: Colors.white.withOpacity(0.4)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 17),
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

class _RailLogout extends StatelessWidget {
  const _RailLogout();
  @override
  Widget build(BuildContext context) => const LogoutButton();
}

// Mobile sub-widgets
class _MobileChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  const _MobileChip({
    required this.icon,
    required this.label,
    this.loading = false,
  });
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
        Icon(icon, color: Colors.white, size: 13),
        const SizedBox(width: 5),
        loading
            ? const SizedBox(
              width: 10,
              height: 10,
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
                fontSize: 11,
              ),
            ),
      ],
    ),
  );
}

class _MobileStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MobileStatPill({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.shade200,
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    ),
  );
}
