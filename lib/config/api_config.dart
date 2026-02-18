// lib/config/api_config.dart
class ApiConfig {
  // ✅ FIXED: Support multiple environments
  static const String _devUrl = 'https://ams-backend-o4va.onrender.com';
  static const String _prodUrl = 'https://your-production-url.com';

  // Change this based on your environment
  static const bool isDevelopment = true;

  static String get baseUrl => isDevelopment ? _devUrl : _prodUrl;

  // API Endpoints
  static String get authLogin => '$baseUrl/api/auth/login';
  static String get authRegister => '$baseUrl/api/auth/register';

  static String get teacherClasses => '$baseUrl/api/teacher/classes';
  static String get teacherRecordScan => '$baseUrl/api/teacher/record-scan';
  static String teacherStudents(String lrn) =>
      '$baseUrl/api/teacher/students/$lrn';
  static String teacherClassStudents(String classId) =>
      '$baseUrl/api/teacher/classes/$classId/students';

  static String get studentProfile => '$baseUrl/api/student/profile';
  static String get studentClasses => '$baseUrl/api/student/classes';
  static String get studentAttendance => '$baseUrl/api/student/attendance';

  static String get adminTeachers => '$baseUrl/api/admin/teachers';
  static String get adminStudents => '$baseUrl/api/admin/students';
  static String get adminClasses => '$baseUrl/api/admin/classes';
  static String adminTeacherClasses(String teacherId) =>
      '$baseUrl/api/admin/teachers/$teacherId/classes';
  static String adminDeleteClass(String classId) =>
      '$baseUrl/api/admin/classes/$classId';

  // Timeout duration
  static const Duration timeout = Duration(seconds: 10);

  // Headers helper
  static Map<String, String> headers(String? token) {
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}
