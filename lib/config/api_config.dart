// lib/config/api_config.dart
class ApiConfig {
  static const String _devUrl = 'https://ams-backend-o4va.onrender.com';
  static const String _prodUrl = 'https://your-production-url.com';

  static const bool isDevelopment = true;

  static String get baseUrl => isDevelopment ? _devUrl : _prodUrl;

  // ── Auth ──────────────────────────────────────────────────────────────
  static String get authLogin => '$baseUrl/api/auth/login';
  static String get authRegister => '$baseUrl/api/auth/register';

  // ── Teacher ───────────────────────────────────────────────────────────
  static String get teacherClasses => '$baseUrl/api/teacher/classes';
  static String get teacherRecordScan => '$baseUrl/api/teacher/record-scan';
  static String teacherStudents(String lrn) =>
      '$baseUrl/api/teacher/students/$lrn';
  static String teacherClassStudents(String classId) =>
      '$baseUrl/api/teacher/classes/$classId/students';

  /// SF2 attendance data: attendance per student per day for a given month/year.
  /// Query params: ?month=<1-12>&year=<yyyy>
  static String teacherSF2Attendance(String classId, {int? month, int? year}) {
    final now = DateTime.now();
    final m = month ?? now.month;
    final y = year ?? now.year;
    return '$baseUrl/api/teacher/classes/$classId/sf2-attendance?month=$m&year=$y';
  }

  // ── Student ───────────────────────────────────────────────────────────
  static String get studentProfile => '$baseUrl/api/student/profile';
  static String get studentClasses => '$baseUrl/api/student/classes';
  static String get studentAttendance => '$baseUrl/api/student/attendance';

  // ── Admin — READ ──────────────────────────────────────────────────────
  static String get adminTeachers => '$baseUrl/api/admin/teachers';
  static String get adminStudents => '$baseUrl/api/admin/students';
  static String get adminClasses => '$baseUrl/api/admin/classes';

  // ── Admin — Teacher CRUD ──────────────────────────────────────────────
  /// POST   → create teacher
  /// (use adminTeachers for POST)

  /// PUT /api/admin/teachers/:id
  static String adminUpdateTeacher(String teacherId) =>
      '$baseUrl/api/admin/teachers/$teacherId';

  /// DELETE /api/admin/teachers/:id
  static String adminDeleteTeacher(String teacherId) =>
      '$baseUrl/api/admin/teachers/$teacherId';

  /// GET  /api/admin/teachers/:id/classes
  static String adminTeacherClasses(String teacherId) =>
      '$baseUrl/api/admin/teachers/$teacherId/classes';

  /// POST /api/admin/teachers/:id/classes  → create class for teacher
  // (same URL as adminTeacherClasses, different method)

  // ── Admin — Student CRUD ──────────────────────────────────────────────
  /// PUT /api/admin/students/:lrn
  static String adminUpdateStudent(String lrn) =>
      '$baseUrl/api/admin/students/$lrn';

  /// DELETE /api/admin/students/:lrn
  static String adminDeleteStudent(String lrn) =>
      '$baseUrl/api/admin/students/$lrn';

  // ── Admin — Class CRUD ────────────────────────────────────────────────
  /// PUT /api/admin/classes/:id
  static String adminUpdateClass(String classId) =>
      '$baseUrl/api/admin/classes/$classId';

  /// DELETE /api/admin/classes/:id
  static String adminDeleteClass(String classId) =>
      '$baseUrl/api/admin/classes/$classId';

  /// GET /api/admin/classes/:classId/students
  static String adminClassStudents(String classId) =>
      '$baseUrl/api/admin/classes/$classId/students';

  /// DELETE /api/admin/classes/:classId/students/:lrn
  static String adminRemoveStudentFromClass(String classId, String lrn) =>
      '$baseUrl/api/admin/classes/$classId/students/$lrn';

  // ── Timeout & Headers ─────────────────────────────────────────────────
  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> headers(String? token) {
    final Map<String, String> h = {'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }
}
