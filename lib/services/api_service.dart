// filename: lib/services/api_service.dart 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'config.dart';

class ApiService {
  final String baseUrl = Config.baseUrl;
  final Logger logger = Logger();

  bool _isValidEmail(String email) {
    final emailRegExp = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    return emailRegExp.hasMatch(email);
  }

  // Sign up child functionality
  Future<bool> signUpChild(String email, String username, String password, int day, int month, int year) async {
    if (!_isValidEmail(email)) {
      logger.e('Invalid email format');
      throw Exception('Invalid email format');
    }
    if (username.isEmpty) {
      logger.e('Invalid username');
      throw Exception('Invalid username');
    }
    if (password.isEmpty || password.length < 6) {
      logger.e('Invalid password');
      throw Exception('Invalid password');
    }
    if (!_isValidDate(day, month, year)) {
      logger.e('Invalid date of birth');
      throw Exception('Invalid date of birth');
    }

    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/child-signup'),  // Updated URL
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'username': username,
          'password': password,
          'day': day,
          'month': month,
          'year': year,
        }),
      );
      logger.d('Response status: ${response.statusCode}');
      logger.d('Response body: ${response.body}');
      if (response.statusCode == 201) {
        return true;
      } else {
        logger.e('Failed to sign up child: ${response.body}');
        return false;
      }
    } catch (e) {
      logger.e('Exception during child sign up: $e');
      throw Exception('Failed to sign up child: $e');
    }
  }

  // Login child functionality
  Future<Map<String, dynamic>> loginChild(String username, String password) async {
    logger.d('Attempting to log in with username: $username');

    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/child-login'),  // Updated URL
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, String>{
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 20));  // Timeout handling

      logger.d('Response status: ${response.statusCode}');
      logger.d('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('childId')) {
          return {'success': true, 'childId': data['childId']};
        } else {
          return {'success': false};
        }
      } else {
        logger.e('Login failed: ${response.body}');
        return {'success': false};
      }
    } catch (e) {
      logger.e('Exception during child login: $e');
      throw Exception('Failed to login child: $e');
    }
  }

  // Forgot password functionality
  Future<bool> resetPassword(String email) async {
    if (!_isValidEmail(email)) {
      logger.e('Invalid email format');
      throw Exception('Invalid email format');
    }

    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/forgot-password'),  // Endpoint for forgot password
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      logger.d('Response status: ${response.statusCode}');
      logger.d('Response body: ${response.body}');

      if (response.statusCode == 200) {
        logger.d('Password reset link sent to $email');
        return true;
      } else {
        logger.e('Failed to send password reset link: ${response.body}');
        return false;
      }
    } catch (e) {
      logger.e('Exception during password reset: $e');
      throw Exception('Failed to send password reset link: $e');
    }
  }

  // Helper function to validate the date
  bool _isValidDate(int day, int month, int year) {
    try {
      final date = DateTime(year, month, day);
      final now = DateTime.now();
      return date.isBefore(now);
    } catch (e) {
      return false;
    }
  }
}


/*gana ni ge upadte lang kay mag butang ug forgot password link
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'config.dart'; 

class ApiService {
  final String baseUrl = Config.baseUrl;
  final Logger logger = Logger();

  bool _isValidEmail(String email) {
    final emailRegExp = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    return emailRegExp.hasMatch(email);
  }

  bool _isValidUsername(String username) {
    return username.isNotEmpty;
  }

  bool _isValidPassword(String password) {
    return password.isNotEmpty && password.length >= 6;
  }

  bool _isValidDate(int day, int month, int year) {
    try {
      final date = DateTime(year, month, day);
      final now = DateTime.now();
      return date.isBefore(now);
    } catch (e) {
      return false;
    }
  }

  Future<bool> signUpChild(String email, String username, String password, int day, int month, int year) async {
    if (!_isValidEmail(email)) {
      logger.e('Invalid email format');
      throw Exception('Invalid email format');
    }
    if (!_isValidUsername(username)) {
      logger.e('Invalid username');
      throw Exception('Invalid username');
    }
    if (!_isValidPassword(password)) {
      logger.e('Invalid password');
      throw Exception('Invalid password');
    }
    if (!_isValidDate(day, month, year)) {
      logger.e('Invalid date of birth');
      throw Exception('Invalid date of birth');
    }

    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/child-signup'),  // Updated URL to include /api prefix
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'username': username,
          'password': password,
          'day': day,
          'month': month,
          'year': year,
        }),
      );
      logger.d('Response status: ${response.statusCode}');
      logger.d('Response body: ${response.body}');
      if (response.statusCode == 201) {
        return true;
      } else {
        logger.e('Failed to sign up child: ${response.body}');
        return false;
      }
    } catch (e) {
      logger.e('Exception during child sign up: $e');
      throw Exception('Failed to sign up child: $e');
    }
  }

  Future<Map<String, dynamic>> loginChild(String username, String password) async {
    // Using logger instead of print
    logger.d('Attempting to log in with username: $username, password: $password');

    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/child-login'),  // Updated URL to include /api prefix
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, String>{
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 20)); // Increase timeout duration

      logger.d('Response status: ${response.statusCode}');
      logger.d('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('childId')) {
          return {'success': true, 'childId': data['childId']};
        } else {
          return {'success': false};
        }
      } else {
        logger.e('Login failed: ${response.body}');
        return {'success': false};
      }
    } catch (e) {
      logger.e('Exception during child login: $e');
      throw Exception('Failed to login child: $e');
    }
  }
}
*/
/*
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'config.dart'; 

class ApiService {
  final String baseUrl = Config.baseUrl;
  final Logger logger = Logger();

  bool _isValidEmail(String email) {
    final emailRegExp = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    return emailRegExp.hasMatch(email);
  }

  bool _isValidUsername(String username) {
    return username.isNotEmpty;
  }

  bool _isValidPassword(String password) {
    return password.isNotEmpty && password.length >= 6;
  }

  bool _isValidDate(int day, int month, int year) {
    try {
      final date = DateTime(year, month, day);
      final now = DateTime.now();
      return date.isBefore(now);
    } catch (e) {
      return false;
    }
  }

  Future<bool> signUpChild(String email, String username, String password, int day, int month, int year) async {
    if (!_isValidEmail(email)) {
      logger.e('Invalid email format');
      throw Exception('Invalid email format');
    }
    if (!_isValidUsername(username)) {
      logger.e('Invalid username');
      throw Exception('Invalid username');
    }
    if (!_isValidPassword(password)) {
      logger.e('Invalid password');
      throw Exception('Invalid password');
    }
    if (!_isValidDate(day, month, year)) {
      logger.e('Invalid date of birth');
      throw Exception('Invalid date of birth');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/child-signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'username': username,
          'password': password,
          'day': day,
          'month': month,
          'year': year,
        }),
      );
      logger.d('Response status: ${response.statusCode}');
      logger.d('Response body: ${response.body}');
      if (response.statusCode == 201) {
        return true;
      } else {
        logger.e('Failed to sign up child: ${response.body}');
        return false;
      }
    } catch (e) {
      logger.e('Exception during child sign up: $e');
      throw Exception('Failed to sign up child: $e');
    }
  }

  Future<Map<String, dynamic>> loginChild(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/child-login'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, String>{
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 20)); // Increase timeout duration

      logger.d('Response status: ${response.statusCode}');
      logger.d('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('childId')) {
          return {'success': true, 'childId': data['childId']};
        } else {
          return {'success': false};
        }
      } else {
        return {'success': false};
      }
    } catch (e) {
      logger.e('Exception during child login: $e');
      throw Exception('Failed to login child: $e');
    }
  }
}
*/