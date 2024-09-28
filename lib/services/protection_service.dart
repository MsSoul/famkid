// filename: services/protection_service.dart (locking device and blocking apps ni sya)
import 'dart:async'; // For Timer
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:mongo_dart/mongo_dart.dart'; // For ObjectId handling
import '../services/config.dart';  // Import Config for baseUrl
import '../services/app_management_service.dart'; // Import AppManagementService

final Logger logger = Logger();

class ProtectionService {
  late Timer _timer; // Timer for periodic device lock check
  final String _baseUrl = Config.baseUrl; // Base URL from Config
  final AppManagementService appManagementService = AppManagementService(); // Create an instance of AppManagementService

  // Fetch the child ID from the backend or any service
  Future<String> fetchChildId() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/child')); // Make a request to get the child ID
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String childId = data['childId'];
        logger.i('Child ID retrieved: $childId');
        return childId;
      } else {
        logger.e('Failed to fetch child ID from server. Status code: ${response.statusCode}');
        throw Exception('Failed to fetch child ID from server.');
      }
    } catch (error) {
      logger.e('Error fetching child ID: $error');
      rethrow; // Propagate error
    }
  }

  // Function to handle the protection action, including blocking apps and locking the device
  Future<void> handleProtectionAction(String childId) async {
  try {
    await appManagementService.fetchAndApplyAppSettings(childId);
    logger.i('Apps blocked successfully.');

    final response = await http.post(
      Uri.parse('$_baseUrl/block-and-run-management'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'childId': childId,
      }),
    );

    if (response.statusCode == 200) {
      logger.i('Device protected successfully');
    } else {
      logger.w('Failed to protect device');
    }

    // Make sure the protection starts after blocking/unblocking apps
    activateProtection(childId);
  } catch (error) {
    logger.e('Error during protection action: $error');
  }
}


  // Activate protection, which includes starting the periodic check for locking
  Future<void> activateProtection(String childId) async {
    try {
      _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) async {
        await DeviceLockService().checkAndHandleDeviceLock(ObjectId.fromHexString(childId));
      });

      logger.i('Protection activated and time management services started.');
    } catch (e) {
      logger.e('Failed to activate protection: $e');
      rethrow; // Use rethrow to preserve stack trace for logging
    }
  }

  // Deactivate protection (stop periodic check)
  void deactivateProtection() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    logger.i('Protection deactivated.');
  }
}

class DeviceLockService {
  // Dummy implementation for locking/unlocking a device, replace this with actual logic
  Future<void> checkAndHandleDeviceLock(ObjectId childId) async {
    // Logic for checking device lock status
    logger.i('Checking lock status for child ID: $childId');
    
    // Implement your logic here (e.g., call a native API or service to lock/unlock)
    // Example:
    // if (remainingTime == 0) {
    //     lockDevice();
    // } else {
    //     unlockDevice();
    // }
  }
}


/*
import 'dart:async'; // For Timer
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../services/config.dart';  // Import Config for baseUrl
import '../services/app_management_service.dart'; // Import AppManagementService

final Logger logger = Logger();

class ProtectionService {
  late Timer _timer;
  final String _baseUrl = Config.baseUrl;
  final AppManagementService appManagementService = AppManagementService(); // Create an instance of AppManagementService

  // Fetch the child ID from the backend or any service
  Future<String> fetchChildId() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/child'));
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String childId = data['childId'];
        logger.i('Child ID retrieved: $childId');
        return childId;
      } else {
        logger.e('Failed to fetch child ID from server. Status code: ${response.statusCode}');
        throw Exception('Failed to fetch child ID from server.');
      }
    } catch (error) {
      logger.e('Error fetching child ID: $error');
      rethrow;
    }
  }

  // Function to handle the protection action, including blocking apps and locking the device
  Future<void> handleProtectionAction(String childId) async {
    try {
      // Step 1: Block the apps (this uses the fetchAndBlockApps method from AppManagementService)
      await appManagementService.fetchAndApplyAppSettings(childId);
      logger.i('Apps blocked successfully.');

      // Step 2: Call the backend service for protection actions (e.g., time management)
      final response = await http.post(
        Uri.parse('$_baseUrl/block-and-run-management'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'childId': childId,
        }),
      );

      if (response.statusCode == 200) {
        logger.i('Device protected successfully');
      } else {
        logger.w('Failed to protect device');
      }

      // Step 3: Start the timer for locking the device if remaining time runs out
      activateProtection(childId);
    } catch (error) {
      logger.e('Error during protection action: $error');
    }
  }

  // Activate protection, which includes starting the periodic check for locking
  Future<void> activateProtection(String childId) async {
    try {
      _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) async {
        await DeviceLockService().checkAndHandleDeviceLock(ObjectId.fromHexString(childId));
      });

      logger.i('Protection activated and time management services started.');
    } catch (e) {
      logger.e('Failed to activate protection: $e');
      rethrow;  // Use rethrow to preserve stack trace for logging
    }
  }

  // Deactivate protection (stop periodic check)
  void deactivateProtection() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    logger.i('Protection deactivated.');
  }
}

class DeviceLockService {
  // Dummy implementation for locking/unlocking a device, you can replace this with actual logic
  Future<void> checkAndHandleDeviceLock(ObjectId childId) async {
    // Logic for checking device lock status
    logger.i('Checking lock status for child ID: $childId');
  }
}

*/

/*wla pani implemenattion sa lock device
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'dart:async'; // For Timer
import 'package:mongo_dart/mongo_dart.dart';
import '../services/config.dart';  // Import Config for baseUrl

final Logger logger = Logger();

class ProtectionService {
  late Timer _timer;
  final String _baseUrl = Config.baseUrl;

  // Fetch the child ID from the backend or any service
Future<String> fetchChildId() async {
  try {
    final response = await http.get(Uri.parse('$_baseUrl/child'));
    logger.i('Response status: ${response.statusCode}');
    logger.i('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String childId = data['childId'];
      logger.i('Child ID retrieved: $childId');
      return childId;
    } else {
      logger.e('Failed to fetch child ID from server. Status code: ${response.statusCode}');
      throw Exception('Failed to fetch child ID from server.');
    }
  } catch (error) {
    logger.e('Error fetching child ID: $error');
    rethrow;
  }
}

  // Function to handle the protection action, which calls the backend service
  Future<void> handleProtectionAction(String childId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/block-and-run-management'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'childId': childId,
        }),
      );

      if (response.statusCode == 200) {
        logger.i('Device protected successfully');
      } else {
        logger.w('Failed to protect device');
      }
    } catch (error) {
      logger.e('Error during protection action: $error');
    }
  }

  // Activate protection, which includes starting the periodic check
  Future<void> activateProtection() async {
    try {
      // Fetch the child ID dynamically
      String childId = await fetchChildId();

      // Start checking the device lock status based on time slots
      _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) async {
        await DeviceLockService().checkAndHandleDeviceLock(ObjectId.fromHexString(childId));
      });

      logger.i('Protection activated and time management services started.');
    } catch (e) {
      logger.e('Failed to activate protection: $e');
      rethrow;  // Use rethrow to preserve stack trace for logging
    }
  }

  // Deactivate protection (stop periodic check)
  void deactivateProtection() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    logger.i('Protection deactivated.');
  }
}

class DeviceLockService {
  // Dummy implementation for locking/unlocking a device, you can replace this with actual logic
  Future<void> checkAndHandleDeviceLock(ObjectId childId) async {
    // Logic for checking device lock status
    logger.i('Checking lock status for child ID: $childId');
  }
}*/