// filename: services/app_time_management_service.dart
import 'package:mongo_dart/mongo_dart.dart';

class AppTimeManagementService {
  final DbCollection remainingAppTimeCollection;
  final DbCollection appTimeManagementCollection;

  AppTimeManagementService({
    required this.remainingAppTimeCollection,
    required this.appTimeManagementCollection,
  });

  // Sync app time slots with remaining time
  Future<void> syncAppTimeSlotsWithRemainingTime(ObjectId childId) async {
    final timeManagementDoc = await appTimeManagementCollection.findOne(where.eq('child_id', childId));
    
    if (timeManagementDoc != null && timeManagementDoc['app_time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['app_time_slots'];

      for (var timeSlot in timeSlots) {
        final slotIdentifier = ObjectId.fromHexString(timeSlot['slot_identifier']);
        final int allowedTime = timeSlot['allowed_time'] ?? 3600;
        final String endTime = timeSlot['end_time']; // Fetch end_time from time slot
        
        final DateTime now = DateTime.now();
        final DateTime slotEndTime = DateTime.parse(endTime); // Assuming end_time is a string in ISO format

        if (now.isAfter(slotEndTime)) {
          // If the current time is after the slot's end time, set remaining time to zero
          await zeroOutRemainingTime(slotIdentifier);
        } else {
          // Initialize the remaining time with the allowed time
          await remainingAppTimeCollection.update(
            where.eq('slot_identifier', slotIdentifier),
            modify.set('remaining_time', allowedTime).set('timestamp', DateTime.now()),
            upsert: true,
          );
        }
      }
    }
  }

  // Function to zero out remaining time if time has passed
  Future<void> zeroOutRemainingTime(ObjectId slotIdentifier) async {
    await remainingAppTimeCollection.update(
      where.eq('slot_identifier', slotIdentifier),
      modify.set('remaining_time', 0).set('timestamp', DateTime.now()),
    );
  }

  // Method to check and update remaining app time
  Future<void> checkAndUpdateRemainingAppTime() async {
    final appTimeSlots = await remainingAppTimeCollection.find().toList();

    for (var timeSlot in appTimeSlots) {
      final slotIdentifier = timeSlot['slot_identifier'] as ObjectId;
      final int allowedTime = timeSlot['allowed_time'] ?? 3600;
      final String endTime = timeSlot['end_time']; // Assuming this field exists
      
      final DateTime now = DateTime.now();
      final DateTime slotEndTime = DateTime.parse(endTime);

      if (now.isAfter(slotEndTime)) {
        // If the current time is after the slot's end time, set remaining time to zero
        await zeroOutRemainingTime(slotIdentifier);
      } else {
        // Update the remaining time based on the allowed time and time passed
        final lastUpdateTime = timeSlot['timestamp'] ?? now;
        final int secondsPassed = now.difference(lastUpdateTime).inSeconds;

        int updatedRemainingTime = allowedTime - secondsPassed;
        if (updatedRemainingTime < 0) updatedRemainingTime = 0;

        await remainingAppTimeCollection.update(
          where.eq('slot_identifier', slotIdentifier),
          modify.set('remaining_time', updatedRemainingTime).set('timestamp', DateTime.now()),
        );
      }
    }
  }
}

/*import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'config.dart'; // Import the Config class

class AppTimeManagementService {
  final DbCollection appTimeManagementCollection;

  AppTimeManagementService({
    required this.appTimeManagementCollection,
  });

  // Fetch app time management data for a child from the server
  Future<List<AppTimeManagement>> getAppTimeManagement(String childId) async {
    final response = await http.get(Uri.parse('${Config.baseUrl}/app-time-management/$childId'));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => AppTimeManagement.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load app time management data');
    }
  }

  // Sync the app time slots with the app time management collection
  Future<void> syncAppTimeManagement(String childId) async {
    List<AppTimeManagement> appTimeManagementData = await getAppTimeManagement(childId);

    for (var timeSlot in appTimeManagementData) {
      final slotIdentifier = ObjectId.parse(timeSlot.slotIdentifier);
      await appTimeManagementCollection.update(
        where.eq('slot_identifier', slotIdentifier),
        modify
            .set('app_name', timeSlot.appName)
            .set('package_name', timeSlot.packageName)
            .set('start_time', timeSlot.startTime)
            .set('end_time', timeSlot.endTime)
            .set('allowed_time', timeSlot.allowedTime)
            .set('timestamp', DateTime.now()),
        upsert: true,
      );
    }
  }
}

// Example model class for AppTimeManagement (adjust as needed)
class AppTimeManagement {
  final String appName;
  final String packageName;
  final String slotIdentifier; // Ensure slotIdentifier is a string representing the ObjectId
  final String startTime;
  final String endTime;
  final int allowedTime;

  AppTimeManagement({
    required this.appName,
    required this.packageName,
    required this.slotIdentifier,
    required this.startTime,
    required this.endTime,
    required this.allowedTime,
  });

  factory AppTimeManagement.fromJson(Map<String, dynamic> json) {
    return AppTimeManagement(
      appName: json['app_name'],
      packageName: json['package_name'],
      slotIdentifier: json['slot_identifier'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      allowedTime: json['allowed_time'],
    );
  }
}
*/