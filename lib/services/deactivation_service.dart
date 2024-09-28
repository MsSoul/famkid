// filename: deactivation_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'config.dart';  // Assuming Config contains your base URL

class DeactivationService {
  final String _baseUrl = Config.baseUrl;
  final Logger logger = Logger();

  // Method to deactivate protection for a specific child
  Future<void> deactivateProtectionForChild(String childId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/remove-protection'),  // Adjust the endpoint to your backend
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'childId': childId,
      }),
    );

    if (response.statusCode == 200) {
      logger.d('Protection removed for child $childId');
    } else {
      throw Exception('Failed to remove protection');
    }
  }
}
