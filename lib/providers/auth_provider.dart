import 'package:attsys/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _role;

  bool get isAuthenticated => _token != null;
  String? get role => _role;

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
    String? sex, // 'Male' or 'Female'
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
      Uri.parse('https://ams-backend-o4va.onrender.com/api/auth/register'),
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
  // ======================
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      Map<String, dynamic> decoded = Jwt.parseJwt(_token!);
      _role = decoded['role'];
      notifyListeners();
    }
  }

  // ======================
  // LOGOUT
  // ======================
  void logout() async {
    _token = null;
    _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
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
}
