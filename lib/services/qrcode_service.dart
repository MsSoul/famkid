//filename:services/qrcode_service.dart 
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';  // Import your Config class for baseUrl
import 'package:logger/logger.dart'; 
import 'package:flutter/foundation.dart';

class QrCodeService {
  Timer? _timer;
  final Logger logger = Logger();  // Create an instance of Logger

  // Start polling for the child profile data in the backend
  void startPollingForChildProfile(String childId, String deviceName, VoidCallback onSuccess) {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final isProfileSaved = await checkDeviceAndProfileMatch(childId, deviceName);
      if (isProfileSaved) {
        stopPolling();
        onSuccess();  // Call the onSuccess callback to display the notification and proceed
      }
    });
  }

  // Stop the polling when necessary
  void stopPolling() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  // Function to check the backend if the device and profile match
  Future<bool> checkDeviceAndProfileMatch(String childId, String deviceName) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/api/compare-device-and-profile?childId=$childId&deviceName=$deviceName'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] ?? false;
      } else {
        logger.e('Failed to check child profile. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      logger.e('Error checking profile: $e');
      return false;
    }
  }
}


/*
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';  // Import your Config class for baseUrl
import 'package:logger/logger.dart'; 
import 'package:flutter/foundation.dart';

class QrCodeService {
  Timer? _timer;
  final Logger logger = Logger();  // Create an instance of Logger

  // Start polling for the child profile data in the backend
  void startPollingForChildProfile(String childId, String macAddress, VoidCallback onSuccess) {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final isProfileSaved = await checkDeviceAndProfileMatch(childId, macAddress);
      if (isProfileSaved) {
        stopPolling();
        onSuccess();  // Call the onSuccess callback to display the notification and proceed
      }
    });
  }

  // Stop the polling when necessary
  void stopPolling() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  // Function to check the backend if the device and profile match
  Future<bool> checkDeviceAndProfileMatch(String childId, String deviceName) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/api/compare-device-and-profile?childId=$childId&deviceName=$deviceName'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] ?? false;
      } else {
        logger.e('Failed to check child profile. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      logger.e('Error checking profile: $e');
      return false;
    }
  }
}
*/