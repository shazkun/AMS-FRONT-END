// lib/config/api_config.dart
class ApiConfig {
  static const String _devUrl = 'https://ams-backend-o4va.onrender.com';
  static const String _prodUrl = 'https://your-production-url.com';

  static const bool isDevelopment = true;

  static String get baseUrl => isDevelopment ? _devUrl : _prodUrl;

  // Auth
  static String get authLogin => '$baseUrl/api/auth/login';
  static String get authRegister => '$baseUrl/api/auth/register';

  // Teacher
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

  // Student
  static String get studentProfile => '$baseUrl/api/student/profile';
  static String get studentClasses => '$baseUrl/api/student/classes';
  static String get studentAttendance => '$baseUrl/api/student/attendance';

  // Admin
  static String get adminTeachers => '$baseUrl/api/admin/teachers';
  static String get adminStudents => '$baseUrl/api/admin/students';
  static String get adminClasses => '$baseUrl/api/admin/classes';
  static String adminTeacherClasses(String teacherId) =>
      '$baseUrl/api/admin/teachers/$teacherId/classes';
  static String adminDeleteClass(String classId) =>
      '$baseUrl/api/admin/classes/$classId';

  // Timeout
  static const Duration timeout = Duration(seconds: 30);

  // Headers helper
  static Map<String, String> headers(String? token) {
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}
