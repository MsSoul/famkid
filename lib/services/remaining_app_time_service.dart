// filename: services/remaining_app_time_service.dart
// filename: services/remaining_app_time_service.dart
import 'package:mongo_dart/mongo_dart.dart';
import 'package:logging/logging.dart';
import '../algorithm/tokenbucket.dart';

class AppTimeManagementService {
  final DbCollection remainingAppTimeCollection;
  final DbCollection appTimeManagementCollection;
  final Logger _logger = Logger('AppTimeManagementService');

  AppTimeManagementService({
    required this.remainingAppTimeCollection,
    required this.appTimeManagementCollection,
  });

  // Sync app time slots with remaining time
  Future<void> syncAppTimeSlotsWithRemainingTime(ObjectId childId) async {
    final timeManagementDoc = await appTimeManagementCollection.findOne(where.eq('child_id', childId));

    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];

      for (var timeSlot in timeSlots) {
        final String? slotIdentifierStr = timeSlot['slot_identifier'];
        final String? endTimeStr = timeSlot['end_time'];

        if (slotIdentifierStr == null || endTimeStr == null) continue;

        final ObjectId slotIdentifier = ObjectId.fromHexString(slotIdentifierStr);
        final DateTime now = DateTime.now();
        final DateTime slotEndTime = DateTime.parse(endTimeStr);
        final int allowedTime = timeSlot['allowed_time'] ?? 3600;

        if (now.isAfter(slotEndTime)) {
          // Zero out remaining time if slot has ended
          await zeroOutRemainingTime(slotIdentifier);
        } else {
          // Set initial remaining time for active slot
          await remainingAppTimeCollection.update(
            where.eq('slot_identifier', slotIdentifier),
            modify.set('remaining_time', allowedTime).set('timestamp', now),
            upsert: true,
          );
        }
      }
    } else {
      _logger.warning('No time slots found for child ID $childId');
    }
  }

  // Function to zero out remaining time if slot has ended
  Future<void> zeroOutRemainingTime(ObjectId slotIdentifier) async {
    _logger.info('Zeroing out remaining time for slot $slotIdentifier');
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
      final String endTimeStr = timeSlot['end_time'] ?? '';

      final DateTime now = DateTime.now();
      final DateTime slotEndTime = DateTime.parse(endTimeStr);

      if (now.isAfter(slotEndTime)) {
        // Zero out remaining time if slot has ended
        await zeroOutRemainingTime(slotIdentifier);
      } else {
        // Calculate remaining time based on elapsed time
        final lastUpdateTime = timeSlot['timestamp'] ?? now;
        final int secondsPassed = now.difference(lastUpdateTime).inSeconds;

        int updatedRemainingTime = allowedTime - secondsPassed;
        updatedRemainingTime = updatedRemainingTime.clamp(0, allowedTime);

        await remainingAppTimeCollection.update(
          where.eq('slot_identifier', slotIdentifier),
          modify.set('remaining_time', updatedRemainingTime).set('timestamp', now),
        );
        _logger.info('Updated remaining time for slot $slotIdentifier: $updatedRemainingTime seconds remaining');
      }
    }
  }

  // Use time from the bucket and update the database
  Future<void> useTime(dynamic slotIdentifier, int deltaTime) async {
    final bucket = await getTokenBucket(slotIdentifier);
    bucket.updateRemainingTime();

    if (bucket.tokens > 0) {
      bucket.tokens -= deltaTime;
      if (bucket.tokens < 0) bucket.tokens = 0;

      await updateRemainingTime(slotIdentifier, bucket);
    } else {
      await lockApp(slotIdentifier); // Lock app if tokens are zero
    }
  }

  // Function to lock the app when time runs out
  Future<void> lockApp(dynamic slotIdentifier) async {
    final document = await remainingAppTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) return;

    final ObjectId childId = document['child_id'];
    await _lockAppBackend(childId);
  }

  // Function to call backend and lock app
  Future<void> _lockAppBackend(ObjectId childId) async {
    _logger.info("Locking app for child $childId");
    // Implement backend logic for app lock
  }

  // Midnight reset functionality within the service
  Future<void> resetRemainingTimeAtMidnight() async {
    while (true) {
      final DateTime now = DateTime.now();
      final DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);

      final Duration timeUntilMidnight = nextMidnight.difference(now);
      await Future.delayed(timeUntilMidnight);

      final timeSlots = await appTimeManagementCollection.find().toList();
      for (var slot in timeSlots) {
        final ObjectId slotIdentifier = slot['slot_identifier'];
        final int allowedTime = slot['allowed_time'] ?? 3600;

        // Reset remaining time at midnight
        await remainingAppTimeCollection.update(
          where.eq('slot_identifier', slotIdentifier),
          modify.set('remaining_time', allowedTime).set('timestamp', DateTime.now()),
          upsert: true,
        );
        _logger.info('Reset remaining time for slot $slotIdentifier to $allowedTime seconds at midnight');
      }
    }
  }

  // TokenBucket and remaining time functions for specific slot
  Future<TokenBucket> getTokenBucket(dynamic slotIdentifier) async {
    final document = await remainingAppTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) throw Exception("Slot not found.");

    final int remainingTime = document['remaining_time'] ?? 0;
    final DateTime lastRefill = document['timestamp'] ?? DateTime.now();

    final bucket = TokenBucket(capacity: remainingTime, refillRate: 1);
    bucket.tokens = remainingTime;
    bucket.lastRefill = lastRefill;

    final int secondsPassed = DateTime.now().difference(lastRefill).inSeconds;
    if (secondsPassed > 0) {
      bucket.updateRemainingTime();
      if (bucket.tokens <= 0) bucket.tokens = 0;
    }

    return bucket;
  }

  Future<void> updateRemainingTime(dynamic slotIdentifier, TokenBucket bucket) async {
    await remainingAppTimeCollection.update(
      where.eq('slot_identifier', slotIdentifier),
      modify.set('remaining_time', bucket.getRemainingTime()).set('timestamp', DateTime.now()),
    );
  }
}

/* gana na ni kaso update lang para sa remaining time
import 'package:mongo_dart/mongo_dart.dart';
import 'package:logging/logging.dart';
import '../algorithm/tokenbucket.dart';

class AppTimeManagementService {
  final DbCollection remainingAppTimeCollection;
  final DbCollection appTimeManagementCollection;
  final Logger _logger = Logger('AppTimeManagementService');

  AppTimeManagementService({
    required this.remainingAppTimeCollection,
    required this.appTimeManagementCollection,
  });

  // Sync app time slots with remaining time
  Future<void> syncAppTimeSlotsWithRemainingTime(ObjectId childId) async {
    final timeManagementDoc = await appTimeManagementCollection.findOne(where.eq('child_id', childId));
    
    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];

      for (var timeSlot in timeSlots) {
        final String? slotIdentifierStr = timeSlot['slot_identifier'];
        final String? endTimeStr = timeSlot['end_time'];
        
        if (slotIdentifierStr == null || endTimeStr == null) continue;

        final ObjectId slotIdentifier = ObjectId.fromHexString(slotIdentifierStr);
        final DateTime now = DateTime.now();
        final DateTime slotEndTime = DateTime.parse(endTimeStr);
        final int allowedTime = timeSlot['allowed_time'] ?? 3600;

        if (now.isAfter(slotEndTime)) {
          // Zero out remaining time if slot has ended
          await zeroOutRemainingTime(slotIdentifier);
        } else {
          // Set initial remaining time for active slot
          await remainingAppTimeCollection.update(
            where.eq('slot_identifier', slotIdentifier),
            modify.set('remaining_time', allowedTime).set('timestamp', now),
            upsert: true,
          );
        }
      }
    }
  }

  // Function to zero out remaining time if slot has ended
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
      final String endTimeStr = timeSlot['end_time'] ?? '';
      
      final DateTime now = DateTime.now();
      final DateTime slotEndTime = DateTime.parse(endTimeStr);

      if (now.isAfter(slotEndTime)) {
        // Zero out remaining time if slot has ended
        await zeroOutRemainingTime(slotIdentifier);
      } else {
        // Calculate remaining time based on elapsed time
        final lastUpdateTime = timeSlot['timestamp'] ?? now;
        final int secondsPassed = now.difference(lastUpdateTime).inSeconds;

        int updatedRemainingTime = allowedTime - secondsPassed;
        updatedRemainingTime = updatedRemainingTime.clamp(0, allowedTime);

        await remainingAppTimeCollection.update(
          where.eq('slot_identifier', slotIdentifier),
          modify.set('remaining_time', updatedRemainingTime).set('timestamp', now),
        );
      }
    }
  }

  // Use time from the bucket and update the database
  Future<void> useTime(dynamic slotIdentifier, int deltaTime) async {
    final bucket = await getTokenBucket(slotIdentifier);
    bucket.updateRemainingTime();

    if (bucket.tokens > 0) {
      bucket.tokens -= deltaTime;
      if (bucket.tokens < 0) bucket.tokens = 0;

      await updateRemainingTime(slotIdentifier, bucket);
    } else {
      await lockApp(slotIdentifier); // Lock app if tokens are zero
    }
  }

  // Function to lock the app when time runs out
  Future<void> lockApp(dynamic slotIdentifier) async {
    final document = await remainingAppTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) return;

    final ObjectId childId = document['child_id'];
    await _lockAppBackend(childId);
  }

  // Function to call backend and lock app
  Future<void> _lockAppBackend(ObjectId childId) async {
    _logger.info("Locking app for child $childId");
    // Implement backend logic for app lock
  }

  // Midnight reset functionality within the service
  Future<void> resetRemainingTimeAtMidnight() async {
    final DateTime now = DateTime.now();
    final DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);

    while (true) {
      final Duration timeUntilMidnight = nextMidnight.difference(DateTime.now());
      await Future.delayed(timeUntilMidnight);

      final timeSlots = await appTimeManagementCollection.find().toList();
      for (var slot in timeSlots) {
        final ObjectId slotIdentifier = slot['slot_identifier'];
        final int allowedTime = slot['allowed_time'] ?? 3600;

        // Reset remaining time at midnight
        await remainingAppTimeCollection.update(
          where.eq('slot_identifier', slotIdentifier),
          modify.set('remaining_time', allowedTime).set('timestamp', DateTime.now()),
          upsert: true,
        );
      }
      await Future.delayed(const Duration(hours: 24));
    }
  }

  // TokenBucket and remaining time functions for specific slot
  Future<TokenBucket> getTokenBucket(dynamic slotIdentifier) async {
    final document = await remainingAppTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) throw Exception("Slot not found.");

    final int remainingTime = document['remaining_time'] ?? 0;
    final DateTime lastRefill = document['timestamp'] ?? DateTime.now();

    final bucket = TokenBucket(capacity: remainingTime, refillRate: 1);
    bucket.tokens = remainingTime;
    bucket.lastRefill = lastRefill;

    final int secondsPassed = DateTime.now().difference(lastRefill).inSeconds;
    if (secondsPassed > 0) {
      bucket.updateRemainingTime();
      if (bucket.tokens <= 0) bucket.tokens = 0;
    }

    return bucket;
  }

  Future<void> updateRemainingTime(dynamic slotIdentifier, TokenBucket bucket) async {
    await remainingAppTimeCollection.update(
      where.eq('slot_identifier', slotIdentifier),
      modify.set('remaining_time', bucket.getRemainingTime()).set('timestamp', DateTime.now()),
    );
  }
}
*/
/*e update para mag update ang backend remaining app time
// filename: services/remaining_app_time_service.dart
import 'package:mongo_dart/mongo_dart.dart';
import '../algorithm/tokenbucket.dart';
import 'package:logging/logging.dart';

class RemainingAppTimeService {
  final DbCollection remainingAppTimeCollection;
  final DbCollection appTimeManagementCollection;
  final Logger _logger = Logger('RemainingAppTimeService');

  RemainingAppTimeService({
    required this.remainingAppTimeCollection,
    required this.appTimeManagementCollection,
  });

  // Fetch the TokenBucket for a specific app slot
  Future<TokenBucket> getTokenBucket(dynamic slotIdentifier) async {
    final document = await remainingAppTimeCollection.findOne(
      where.eq('time_slots.slot_identifier', slotIdentifier),
    );

    if (document == null) {
      throw Exception("Slot not found.");
    }

    final timeSlot = document['time_slots'].firstWhere((slot) => slot['slot_identifier'] == slotIdentifier.toString());
    final int remainingTime = timeSlot['remaining_time'] ?? 0;
    final DateTime lastRefill = timeSlot['timestamp']?.toDateTime() ?? DateTime.now();

    final TokenBucket bucket = TokenBucket(capacity: remainingTime, refillRate: 1);
    bucket.tokens = remainingTime; // Set the current remaining time
    bucket.lastRefill = lastRefill; // Set the last refill time

    // Check if time has passed and update tokens accordingly
    final DateTime now = DateTime.now();
    final int secondsPassed = now.difference(lastRefill).inSeconds;

    if (secondsPassed > 0) {
      bucket.updateRemainingTime();
      if (bucket.tokens <= 0) {
        bucket.tokens = 0;
      }
    }

    return bucket;
  }

  // Update the remaining time in the database
  Future<void> updateRemainingTime(dynamic slotIdentifier, TokenBucket bucket) async {
    await remainingAppTimeCollection.update(
      where.eq('time_slots.slot_identifier', slotIdentifier),
      modify.set('time_slots.\$.remaining_time', bucket.getRemainingTime())
          .set('time_slots.\$.timestamp', DateTime.now()),
    );
  }

  // Use time from the bucket and update the database
  Future<void> useTime(dynamic slotIdentifier, int deltaTime) async {
    final bucket = await getTokenBucket(slotIdentifier);
    bucket.updateRemainingTime();

    if (bucket.tokens > 0) {
      bucket.tokens -= deltaTime; // Deduct used time
      if (bucket.tokens < 0) {
        bucket.tokens = 0; // Ensure tokens do not go below zero
      }
      await updateRemainingTime(slotIdentifier, bucket);
    } else {
      await lockApp(slotIdentifier); // Lock the app if tokens are zero
    }
  }

  // Function to lock the app when time runs out
  Future<void> lockApp(dynamic slotIdentifier) async {
    // Fetch the child_id associated with the slot
    final document = await remainingAppTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) {
      throw Exception("Slot not found.");
    }

    final ObjectId childId = document['child_id'];

    // Call the backend to lock the app
    await _lockAppBackend(childId);
  }

  // Function to call the backend and lock the app
  Future<void> _lockAppBackend(ObjectId childId) async {
    // Use logger instead of print
    _logger.info("Locking app for child $childId");
    // Implement the logic to send a request to the backend to lock the app
  }

  // Reset the slot to the max time
  Future<void> resetSlot(dynamic slotIdentifier) async {
    final document = await appTimeManagementCollection.findOne(
      where.eq('time_slots.slot_identifier', slotIdentifier),
    );

    if (document == null) {
      throw Exception("Slot not found in app time management.");
    }

    final timeSlot = document['time_slots'].firstWhere((slot) => slot['slot_identifier'] == slotIdentifier.toString());
    final int allowedTime = timeSlot['allowed_time'];

    final TokenBucket bucket = TokenBucket(capacity: allowedTime, refillRate: 1);
    bucket.resetRemainingTime();
    await updateRemainingTime(slotIdentifier, bucket);
  }

  // Method to sync app time slots from time management to remaining time management
  // Method to sync app time slots from time management to remaining time management
Future<void> syncAppTimeSlotsWithRemainingTime(dynamic childId, DateTime deviceTime) async {
    final timeManagementDoc = await appTimeManagementCollection.findOne(where.eq('child_id', childId));

    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];

      for (var timeSlot in timeSlots) {
        final String? slotIdentifierStr = timeSlot['slot_identifier'];
        final String? startTimeStr = timeSlot['start_time'];
        final String? endTimeStr = timeSlot['end_time'];

        // Log the current slot details for debugging
        _logger.info("Processing slot with details: $timeSlot");

        if (slotIdentifierStr == null || startTimeStr == null || endTimeStr == null) {
          _logger.severe("Start time, end time, or slot identifier is missing for slot: $slotIdentifierStr. Skipping update.");
          continue; // Skip if any key fields are missing
        }

        final ObjectId slotIdentifier = ObjectId.fromHexString(slotIdentifierStr);
        final DateTime slotStartTime = DateTime.parse(startTimeStr);
        final DateTime slotEndTime = DateTime.parse(endTimeStr);
        final int allowedTime = timeSlot['allowed_time'] ?? 3600;

        if (deviceTime.isAfter(slotEndTime)) {
          // Zero out remaining time if device time is after the slot's end time
          await zeroOutRemainingTime(slotIdentifier);
        } else {
          // Update remaining time if within the time slot
          await remainingAppTimeCollection.update(
            where.eq('time_slots.slot_identifier', slotIdentifier),
            modify.set('time_slots.\$.remaining_time', allowedTime)
                  .set('time_slots.\$.timestamp', deviceTime),
            upsert: true,
          );
        }
      }
    } else {
      _logger.warning("No time slots found for child: $childId.");
    }
}


  // Function to zero out remaining time if the time slot has ended
  Future<void> zeroOutRemainingTime(dynamic slotIdentifier) async {
    final bucket = await getTokenBucket(slotIdentifier);

    if (bucket.getRemainingTime() > 0) {
      bucket.tokens = 0;
      await updateRemainingTime(slotIdentifier, bucket);
    }
  }
}

*/
/*
import 'package:mongo_dart/mongo_dart.dart'; 
import '../algorithm/tokenbucket.dart';
import 'package:logging/logging.dart';

class RemainingAppTimeService {
  final DbCollection remainingAppTimeCollection;
  final DbCollection appTimeManagementCollection;
  final Logger _logger = Logger('RemainingAppTimeService');

  RemainingAppTimeService({
    required this.remainingAppTimeCollection,
    required this.appTimeManagementCollection,
  });

  // Fetch the TokenBucket for a specific app slot
  Future<TokenBucket> getTokenBucket(dynamic slotIdentifier) async {
    final document = await remainingAppTimeCollection.findOne(
      where.eq('time_slots.slot_identifier', slotIdentifier),
    );

    if (document == null) {
      throw Exception("Slot not found.");
    }

    final timeSlot = document['time_slots'].firstWhere((slot) => slot['slot_identifier'] == slotIdentifier.toString());
    final int remainingTime = timeSlot['remaining_time'] ?? 0;
    final DateTime lastRefill = timeSlot['timestamp']?.toDateTime() ?? DateTime.now();

    final TokenBucket bucket = TokenBucket(capacity: remainingTime, refillRate: 1);
    bucket.tokens = remainingTime; // Set the current remaining time
    bucket.lastRefill = lastRefill; // Set the last refill time

    // Check if time has passed and update tokens accordingly
    final DateTime now = DateTime.now();
    final int secondsPassed = now.difference(lastRefill).inSeconds;

    if (secondsPassed > 0) {
      bucket.updateRemainingTime();
      if (bucket.tokens <= 0) {
        bucket.tokens = 0;
      }
    }

    return bucket;
  }

  // Update the remaining time in the database
  Future<void> updateRemainingTime(dynamic slotIdentifier, TokenBucket bucket) async {
    await remainingAppTimeCollection.update(
      where.eq('time_slots.slot_identifier', slotIdentifier),
      modify.set('time_slots.\$.remaining_time', bucket.getRemainingTime())
          .set('time_slots.\$.timestamp', DateTime.now()),
    );
  }

  // Use time from the bucket and update the database
  Future<void> useTime(dynamic slotIdentifier, int deltaTime) async {
    final bucket = await getTokenBucket(slotIdentifier);
    bucket.updateRemainingTime();

    if (bucket.tokens > 0) {
      bucket.tokens -= deltaTime; // Deduct used time
      if (bucket.tokens < 0) {
        bucket.tokens = 0; // Ensure tokens do not go below zero
      }
      await updateRemainingTime(slotIdentifier, bucket);
    } else {
      await lockApp(slotIdentifier); // Lock the app if tokens are zero
    }
  }

  // Function to lock the app when time runs out
  Future<void> lockApp(dynamic slotIdentifier) async {
    // Fetch the child_id associated with the slot
    final document = await remainingAppTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) {
      throw Exception("Slot not found.");
    }

    final ObjectId childId = document['child_id'];

    // Call the backend to lock the app
    await _lockAppBackend(childId);
  }

  // Function to call the backend and lock the app
  Future<void> _lockAppBackend(ObjectId childId) async {
    // Use logger instead of print
    _logger.info("Locking app for child $childId");
    // Implement the logic to send a request to the backend to lock the app
  }

  // Reset the slot to the max time
  Future<void> resetSlot(dynamic slotIdentifier) async {
    final document = await appTimeManagementCollection.findOne(
      where.eq('time_slots.slot_identifier', slotIdentifier),
    );

    if (document == null) {
      throw Exception("Slot not found in app time management.");
    }

    final timeSlot = document['time_slots'].firstWhere((slot) => slot['slot_identifier'] == slotIdentifier.toString());
    final int allowedTime = timeSlot['allowed_time'];

    final TokenBucket bucket = TokenBucket(capacity: allowedTime, refillRate: 1);
    bucket.resetRemainingTime();
    await updateRemainingTime(slotIdentifier, bucket);
  }

  // Method to sync app time slots from time management to remaining time management
  Future<void> syncAppTimeSlotsWithRemainingTime(dynamic childId) async {
    final timeManagementDoc = await appTimeManagementCollection.findOne(where.eq('child_id', childId));

    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];

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
            where.eq('time_slots.slot_identifier', slotIdentifier),
            modify.set('time_slots.\$.remaining_time', allowedTime)
                  .set('time_slots.\$.timestamp', DateTime.now()),
            upsert: true,
          );
        }
      }
    }
  }

  // Function to zero out remaining time if time has passed
  Future<void> zeroOutRemainingTime(dynamic slotIdentifier) async {
    final bucket = await getTokenBucket(slotIdentifier);

    if (bucket.getRemainingTime() > 0) {
      bucket.tokens = 0;
      await updateRemainingTime(slotIdentifier, bucket);
    }
  }
}*/