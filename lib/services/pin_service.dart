// filename:services/pin_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/config.dart';  // Import Config for baseUrl
import 'package:logger/logger.dart';  // Import logger for logging

class PinService {
  final String baseUrl = Config.baseUrl;
  final Logger logger = Logger();

  // Function to set (or save) the PIN
  Future<void> savePin(String childId, String pin) async {
    logger.i('Saving PIN for childId: $childId');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/set-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'childId': childId, 'pin': pin}),
      );

      logger.i('Response Status Code: ${response.statusCode}');
      logger.i('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        logger.i('PIN saved successfully');
      } else {
        logger.e('Failed to save PIN: ${response.body}');
        throw Exception('Failed to save PIN');
      }
    } catch (error) {
      logger.e('Error occurred while saving PIN: $error');
      throw Exception('Error occurred while saving PIN');
    }
  }

  // Function to verify the PIN
  Future<bool> verifyPin(String childId, String pin) async {
    logger.i('Verifying PIN for childId: $childId');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/verify-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'childId': childId, 'pin': pin}),
      );

      logger.i('Response Status Code: ${response.statusCode}');
      logger.i('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        logger.i('PIN verified successfully');
        return true;
      } else {
        logger.w('PIN verification failed: ${response.body}');
        return false;
      }
    } catch (error) {
      logger.e('Error occurred while verifying PIN: $error');
      throw Exception('Error occurred while verifying PIN');
    }
  }
}


/*
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/config.dart';  // Import Config for baseUrl
import 'package:logger/logger.dart';  // Import logger for logging

class PinService {
  final String baseUrl = Config.baseUrl;
  final Logger logger = Logger();  // Initialize Logger

  // Function to set (or save) the PIN
  Future<void> savePin(String childId, String pin) async {
  final response = await http.post(
     Uri.parse('${Config.baseUrl}/api/set-pin'),  // Ensure the '/api' prefix matches your backend
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'childId': childId, 'pin': pin}),
  );

  if (response.statusCode != 200) {
    logger.e('Failed to set PIN: ${response.body}');  // Log error response
    throw Exception('Failed to set PIN');
  }
}

  // Function to verify the PIN
  Future<bool> verifyPin(String childId, String pin) async {
    final response = await http.post(
       Uri.parse('${Config.baseUrl}/api/set-pin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'childId': childId, 'pin': pin}),
    );

    // Handle different response status codes
    if (response.statusCode == 200) {
      logger.i('PIN verified successfully');
      return true;  // PIN is correct
    } else if (response.statusCode == 400) {
      logger.w('Invalid PIN or request: ${response.body}');
      return false;  // Incorrect PIN or bad request
    } else {
      logger.e('Failed to verify PIN: ${response.body}');
      return false;
    }
  }
}
*/