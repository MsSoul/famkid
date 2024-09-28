//filename:functions/device_lock.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:logger/logger.dart';
import '../services/config.dart'; // Import the Config class for base URL

final Logger _logger = Logger();

class DeviceLockService {
  // Method to check and handle device lock/unlock based on the current time
  Future<void> checkAndHandleDeviceLock(ObjectId childId) async {
    final url = '${Config.baseUrl}/time-management/$childId';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      bool isWithinTimeSlot = _isWithinTimeSlot(data['time_slots']);

      if (isWithinTimeSlot) {
        await unlockDevice(childId);
      } else {
        await lockDevice(childId);
      }
    } else {
      _logger.w('Failed to fetch time management data for child $childId.');
    }
  }

  bool _isWithinTimeSlot(List<dynamic> timeSlots) {
    final DateTime now = DateTime.now();
    for (var timeSlot in timeSlots) {
      final DateTime startTime = DateTime.parse(timeSlot['start_time']);
      final DateTime endTime = DateTime.parse(timeSlot['end_time']);
      if (now.isAfter(startTime) && now.isBefore(endTime)) {
        return true;
      }
    }
    return false;
  }

  Future<void> lockDevice(ObjectId childId) async {
    final url = '${Config.baseUrl}/lock-device/$childId';
    final response = await http.post(Uri.parse(url));

    if (response.statusCode == 200) {
      _logger.i('Device locked for child $childId.');
    } else {
      _logger.w('Failed to lock device for child $childId: ${response.body}');
    }
  }

  Future<void> unlockDevice(ObjectId childId) async {
    final url = '${Config.baseUrl}/unlock-device/$childId';
    final response = await http.post(Uri.parse(url));

    if (response.statusCode == 200) {
      _logger.i('Device unlocked for child $childId.');
    } else {
      _logger.w('Failed to unlock device for child $childId: ${response.body}');
    }
  }
}


/*
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:logging/logging.dart';
import '../services/config.dart'; // Import the Config class for base URL

class DeviceLockService {
  final DbCollection timeManagementCollection;
  final Logger _logger = Logger('DeviceLockService'); // Initialize the logger

  DeviceLockService({
    required this.timeManagementCollection,
  });

  // Method to check and handle device lock/unlock based on the current time
  Future<void> checkAndHandleDeviceLock(ObjectId childId) async {
    final timeManagementDoc = await timeManagementCollection.findOne(where.eq('child_id', childId));

    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];
      final DateTime now = DateTime.now();

      bool isWithinTimeSlot = false;

      for (var timeSlot in timeSlots) {
        final DateTime startTime = DateTime.parse('${now.toIso8601String().split('T').first} ${timeSlot['start_time']}');
        final DateTime endTime = DateTime.parse('${now.toIso8601String().split('T').first} ${timeSlot['end_time']}');

        if (now.isAfter(startTime) && now.isBefore(endTime)) {
          isWithinTimeSlot = true;
          break;
        }
      }

      if (isWithinTimeSlot) {
        await unlockDevice(childId);
      } else {
        await lockDevice(childId);
      }
    }
  }

  Future<void> lockDevice(ObjectId childId) async {
    final url = '${Config.baseUrl}/lock-device/$childId'; // Assuming you have an endpoint to lock the device
    final response = await http.post(Uri.parse(url));

    if (response.statusCode == 200) {
      _logger.info("Device locked for child $childId");
    } else {
      _logger.warning("Failed to lock device for child $childId: ${response.body}");
    }
  }

  Future<void> unlockDevice(ObjectId childId) async {
    final url = '${Config.baseUrl}/unlock-device/$childId'; // Assuming you have an endpoint to unlock the device
    final response = await http.post(Uri.parse(url));

    if (response.statusCode == 200) {
      _logger.info("Device unlocked for child $childId");
    } else {
      _logger.warning("Failed to unlock device for child $childId: ${response.body}");
    }
  }
}
*/