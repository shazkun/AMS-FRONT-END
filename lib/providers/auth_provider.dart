import 'package:attsys/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _role;

  // ── Inactivity session timeout (only while app is running) ─────────────────
  static const Duration _sessionTimeout = Duration(minutes: 30);
  Timer? _inactivityTimer;

  bool get isAuthenticated => _token != null;
  String? get role => _role;

  // Call this on any user interaction to reset the 30-min countdown
  void recordActivity() {
    if (_token == null) return;
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_sessionTimeout, _handleSessionTimeout);
  }

  void _handleSessionTimeout() {
    if (_token == null) return;
    debugPrint('Session timed out after 30 minutes of inactivity');
    logout(isTimeout: true);
  }

  // ======================
  // LOGIN
  // ======================
  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse(ApiConfig.authLogin),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _token = data['token'];
      _role = data['user']['role'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);

      // Start inactivity timer now that user is logged in
      _resetInactivityTimer();

      notifyListeners();
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  // ======================
  // REGISTER — includes sex field for students
  // ======================
  Future<void> register({
    required String username,
    required String password,
    required String role,
    String? lrn,
    String? firstname,
    String? surname,
    String? suffix,
    String? birthday,
    String? sex,
  }) async {
    final body = {'username': username, 'password': password, 'role': role};

    if (role == 'student') {
      body.addAll({
        'lrn': lrn ?? '',
        'firstname': firstname ?? '',
        'surname': surname ?? '',
        'suffix': suffix ?? '',
        'birthday': birthday ?? '',
        if (sex != null && sex.isNotEmpty) 'sex': sex,
      });
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      notifyListeners();
    } else {
      throw Exception('Registration failed: ${response.body}');
    }
  }

  // ======================
  // LOAD TOKEN FROM STORAGE
  // Restores session on app restart/reload.
  // Only clears if the JWT itself is actually expired (7 days server-side).
  // Does NOT log out based on inactivity — timer only runs while app is open.
  // ======================
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('token');

    if (storedToken == null) {
      // No token stored — not logged in
      return;
    }

    try {
      final decoded = Jwt.parseJwt(storedToken);
      final exp = decoded['exp'];

      if (exp != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (DateTime.now().isAfter(expiry)) {
          // JWT genuinely expired on the server side — clear it
          debugPrint('JWT expired. Clearing session.');
          await prefs.remove('token');
          notifyListeners();
          return;
        }
      }

      // Token is valid — restore session
      _token = storedToken;
      _role = decoded['role'];

      // Opening the app counts as activity, start fresh 30-min timer
      _resetInactivityTimer();

      notifyListeners();
    } catch (e) {
      // Malformed token — clear it
      debugPrint('Invalid token: $e. Clearing session.');
      await prefs.remove('token');
      notifyListeners();
    }
  }

  // ======================
  // LOGOUT
  // ======================
  bool _loggedOutDueToTimeout = false;
  bool get loggedOutDueToTimeout => _loggedOutDueToTimeout;

  void logout({bool isTimeout = false}) async {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _token = null;
    _role = null;
    _loggedOutDueToTimeout = isTimeout;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    notifyListeners();
  }

  void clearTimeoutFlag() {
    _loggedOutDueToTimeout = false;
  }

  // ======================
  // GET TOKEN (async)
  // ======================
  Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    return _token;
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }
}
