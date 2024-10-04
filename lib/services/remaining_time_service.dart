// filename: services/remaining_time_service.dart
import 'package:mongo_dart/mongo_dart.dart';
import '../algorithm/tokenbucket.dart';

class RemainingTimeService {
  final DbCollection remainingTimeCollection;
  final DbCollection timeManagementCollection;
  final int maxTime; // Maximum allowable time in seconds
  final int refillRate; // Refill rate per second

  RemainingTimeService(
    this.remainingTimeCollection,
    this.timeManagementCollection, {
    required this.maxTime,
    required this.refillRate,
  });

  // Fetch the TokenBucket for a specific slot, adjusting for actual time passed
  Future<TokenBucket> getTokenBucket(ObjectId slotIdentifier) async {
    final document = await remainingTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) {
      throw Exception("Slot not found.");
    }

    final int remainingTime = document['remaining_time'] ?? maxTime;
    final DateTime lastUpdated = document['timestamp']?.toDate() ?? DateTime.now();

    // Create a new TokenBucket
    final TokenBucket bucket = TokenBucket(capacity: maxTime, refillRate: refillRate);
    bucket.tokens = remainingTime; // Set the current remaining time
    bucket.lastRefill = lastUpdated; // Set the last refill time

    // Adjust tokens based on actual time passed
    bucket.updateRemainingTime();

    return bucket;
  }

  // Update the remaining time in the database
  Future<void> updateRemainingTime(ObjectId slotIdentifier, TokenBucket bucket) async {
    await remainingTimeCollection.update(
      where.eq('slot_identifier', slotIdentifier),
      modify.set('remaining_time', bucket.getRemainingTime()).set('timestamp', DateTime.now()),
    );
  }

  // Use time from the bucket, adjusting for the actual time passed, and update the database
  Future<void> useTime(ObjectId slotIdentifier, int deltaTime) async {
    final bucket = await getTokenBucket(slotIdentifier);

    // Adjust tokens based on time passed
    bucket.updateRemainingTime(); 

    if (bucket.tokens > 0) {
      bucket.tokens -= deltaTime; // Deduct used time in seconds
      await updateRemainingTime(slotIdentifier, bucket);
    } else {
      // Handle scenario when remaining time is zero
      await zeroOutRemainingTime(slotIdentifier);
    }
  }

  // Reset the slot to the max time
  Future<void> resetSlot(ObjectId slotIdentifier) async {
    final bucket = TokenBucket(capacity: maxTime, refillRate: refillRate);
    bucket.resetRemainingTime(); // Reset to full time (max tokens)
    await updateRemainingTime(slotIdentifier, bucket);
  }

  // Sync time slots with remaining time for a specific child, using the actual device clock if needed
  Future<void> syncTimeSlotsWithRemainingTime(dynamic childId) async {
    final timeManagementDoc = await timeManagementCollection.findOne(where.eq('child_id', childId));

    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];

      for (var timeSlot in timeSlots) {
        final slotIdentifier = timeSlot['slot_identifier'];
        final int allowedTime = timeSlot['allowed_time'] ?? maxTime; // allowedTime could be maxTime if not provided
        final String endTime = timeSlot['end_time'];

        final DateTime now = DateTime.now();
        final DateTime slotEndTime = DateTime.parse(endTime);

        // If time has passed the slot end time, zero out remaining time
        if (now.isAfter(slotEndTime)) {
          await zeroOutRemainingTime(slotIdentifier);
        } else {
          // Otherwise, sync the remaining time based on allowed time
          await remainingTimeCollection.update(
            where.eq('slot_identifier', ObjectId.fromHexString(slotIdentifier)),
            modify
                .set('remaining_time', allowedTime)
                .set('timestamp', DateTime.now()), 
            upsert: true,
          );
        }
      }
    } else {
      throw Exception("No time slots found for child: $childId");
    }
  }

  // Function to zero out remaining time if the slot end time has passed
  Future<void> zeroOutRemainingTime(dynamic slotIdentifier) async {
    final bucket = await getTokenBucket(slotIdentifier);

    if (bucket.getRemainingTime() > 0) {
      bucket.tokens = 0;
      await updateRemainingTime(slotIdentifier, bucket);
    }
  }
}

/*
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../algorithm/tokenbucket.dart';

class RemainingTimeService {
  final DbCollection remainingTimeCollection;
  final DbCollection timeManagementCollection;
  final int maxTime; // Maximum allowable time in seconds
  final int refillRate; // Refill rate per second

  RemainingTimeService(
    this.remainingTimeCollection,
    this.timeManagementCollection, {
    required this.maxTime,
    required this.refillRate,
  });

  // Fetch the TokenBucket for a specific slot
  Future<TokenBucket> getTokenBucket(ObjectId slotIdentifier) async {
    final document =
        await remainingTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) {
      throw Exception("Slot not found.");
    }

    final int remainingTime = document['remaining_time'] ?? maxTime;
    final DateTime lastUpdated = document['timestamp']?.toDate() ?? DateTime.now();

    // Create a new TokenBucket
    final TokenBucket bucket = TokenBucket(capacity: maxTime, refillRate: refillRate);
    bucket.tokens = remainingTime; // Set the current remaining time
    bucket.lastRefill = lastUpdated; // Set the last refill time

    // Adjust tokens based on time passed
    bucket.updateRemainingTime();

    return bucket;
  }

  // Update the remaining time in the database
  Future<void> updateRemainingTime(ObjectId slotIdentifier, TokenBucket bucket) async {
    await remainingTimeCollection.update(
      where.eq('slot_identifier', slotIdentifier),
      modify.set('remaining_time', bucket.getRemainingTime()).set('timestamp', DateTime.now()),
    );
  }

  // Use time from the bucket and update the database
  Future<void> useTime(ObjectId slotIdentifier, int deltaTime) async {
    final bucket = await getTokenBucket(slotIdentifier);

    // Refill tokens based on time passed and deduct the time used
    bucket.updateRemainingTime(); // Adjust tokens based on time passed

    if (bucket.tokens > 0) {
      bucket.tokens -= deltaTime; // Deduct used time in seconds
      await updateRemainingTime(slotIdentifier, bucket);
    } else {
      // Handle scenario when remaining time is zero
      await zeroOutRemainingTime(slotIdentifier);
    }
  }

  // Reset the slot to the max time
  Future<void> resetSlot(ObjectId slotIdentifier) async {
    final bucket = TokenBucket(capacity: maxTime, refillRate: refillRate);
    bucket.resetRemainingTime(); // Reset to full time (max tokens)
    await updateRemainingTime(slotIdentifier, bucket);
  }

  // Sync time slots with remaining time for a specific child
  Future<void> syncTimeSlotsWithRemainingTime(dynamic childId) async {
    final timeManagementDoc = await timeManagementCollection.findOne(where.eq('child_id', childId));

    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];

      for (var timeSlot in timeSlots) {
        final slotIdentifier = timeSlot['slot_identifier'];
        final int allowedTime = timeSlot['allowed_time'] ?? 3600;
        final String endTime = timeSlot['end_time'];

        final DateTime now = DateTime.now();
        final DateTime slotEndTime = DateTime.parse(endTime);

        if (now.isAfter(slotEndTime)) {
          await zeroOutRemainingTime(slotIdentifier);
        } else {
          await remainingTimeCollection.update(
            where.eq('slot_identifier', ObjectId.fromHexString(slotIdentifier)),
            modify
                .set('remaining_time', allowedTime)
                .set('timestamp', DateTime.now()),
            upsert: true,
          );
        }
      }
    } else {
      throw Exception("No time slots found for child: $childId");
    }
  }

  // Function to zero out remaining time if the slot end time has passed
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
import 'package:flutter/material.dart'; 
import 'package:mongo_dart/mongo_dart.dart';
import '../algorithm/tokenbucket.dart';

class RemainingTimeService {
  final DbCollection remainingTimeCollection;
  final DbCollection timeManagementCollection;
  final int maxTime; // Maximum allowable time in seconds (B)
  final int refillRate; // Refill rate per second

  RemainingTimeService(
    this.remainingTimeCollection,
    this.timeManagementCollection, {
    required this.maxTime,
    required this.refillRate,
  });

  // Fetch the TokenBucket for a specific slot
  Future<TokenBucket> getTokenBucket(ObjectId slotIdentifier) async {
    final document =
        await remainingTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) {
      throw Exception("Slot not found.");
    }

    final int remainingTime = document['remaining_time'] ?? maxTime;
    final TokenBucket bucket = TokenBucket(capacity: maxTime, refillRate: refillRate);
    bucket.tokens = remainingTime; // Set the current remaining time
    bucket.lastRefill = document['timestamp'] ?? DateTime.now(); // Set the last refill time

    return bucket;
  }

  // Update the remaining time in the database
  Future<void> updateRemainingTime(ObjectId slotIdentifier, TokenBucket bucket) async {
    await remainingTimeCollection.update(
      where.eq('slot_identifier', slotIdentifier),
      modify.set('remaining_time', bucket.getRemainingTime()).set('timestamp', DateTime.now()),
    );
  }

  // Use time from the bucket and update the database
  Future<void> useTime(ObjectId slotIdentifier, int deltaTime) async {
    final bucket = await getTokenBucket(slotIdentifier);
    bucket.updateRemainingTime(); // Refill tokens based on time passed

    if (bucket.tokens > 0) {
      bucket.tokens -= deltaTime; // Deduct used time in seconds
      await updateRemainingTime(slotIdentifier, bucket);
    } else {
      // Handle scenario when remaining time is zero, but no device lock/unlock logic here
      await zeroOutRemainingTime(slotIdentifier);
    }
  }

  // Reset the slot to the max time
  Future<void> resetSlot(ObjectId slotIdentifier) async {
    final bucket = TokenBucket(capacity: maxTime, refillRate: refillRate);
    bucket.resetRemainingTime(); // Reset to full time (max tokens)
    await updateRemainingTime(slotIdentifier, bucket);
  }

  // Sync time slots with remaining time for a specific child
  Future<void> syncTimeSlotsWithRemainingTime(dynamic childId) async {
    final timeManagementDoc = await timeManagementCollection.findOne(where.eq('child_id', childId));
    String logMessages = "[REMAINING TIME SERVICE] Update started.\n";

    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];

      for (var timeSlot in timeSlots) {
        final slotIdentifier = timeSlot['slot_identifier'];
        final int allowedTime = timeSlot['allowed_time'] ?? 3600;
        final String endTime = timeSlot['end_time'];

        final DateTime now = DateTime.now();
        final DateTime slotEndTime = DateTime.parse(endTime);

        if (now.isAfter(slotEndTime)) {
          await zeroOutRemainingTime(slotIdentifier);
          logMessages += "[REMAINING TIME SERVICE] Slot $slotIdentifier zeroed out as time passed.\n";
        } else {
          await remainingTimeCollection.update(
            where.eq('slot_identifier', ObjectId.fromHexString(slotIdentifier)),
            modify
                .set('remaining_time', allowedTime)
                .set('timestamp', DateTime.now()),
            upsert: true,
          );
          logMessages += "[REMAINING TIME SERVICE] Slot $slotIdentifier synced with remaining time $allowedTime.\n";
        }
      }

      logMessages += "[REMAINING TIME SERVICE] Update completed for child: $childId\n";
    } else {
      throw Exception("No time slots found for child: $childId");
    }
  }

  // Function to zero out remaining time if the slot end time has passed
  Future<void> zeroOutRemainingTime(dynamic slotIdentifier) async {
    final bucket = await getTokenBucket(slotIdentifier);

    if (bucket.getRemainingTime() > 0) {
      bucket.tokens = 0;
      await updateRemainingTime(slotIdentifier, bucket);
    }
  }
}
*/
/*mag butang og locking and unlocking function dria

import 'package:flutter/material.dart'; 
import 'package:mongo_dart/mongo_dart.dart';
import '../algorithm/tokenbucket.dart';
//import 'package:logger/logger.dart'; // Import the Logger package

class RemainingTimeService {
  final DbCollection remainingTimeCollection;
  final DbCollection timeManagementCollection;
  final int maxTime; // Maximum allowable time in seconds (B)
  final int refillRate; // Refill rate per second

  RemainingTimeService(
    this.remainingTimeCollection,
    this.timeManagementCollection, {
    required this.maxTime,
    required this.refillRate,
  });

  // Fetch the TokenBucket for a specific slot
  Future<TokenBucket> getTokenBucket(ObjectId slotIdentifier) async {
    final document =
        await remainingTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) {
      throw Exception("Slot not found.");
    }

    final int remainingTime = document['remaining_time'] ?? maxTime;
    final TokenBucket bucket = TokenBucket(capacity: maxTime, refillRate: refillRate);
    bucket.tokens = remainingTime; // Set the current remaining time
    bucket.lastRefill = document['timestamp'] ?? DateTime.now(); // Set the last refill time

    return bucket;
  }

  // Update the remaining time in the database
  Future<void> updateRemainingTime(ObjectId slotIdentifier, TokenBucket bucket) async {
    await remainingTimeCollection.update(
      where.eq('slot_identifier', slotIdentifier),
      modify.set('remaining_time', bucket.getRemainingTime()).set('timestamp', DateTime.now()),
    );
  }

  // Use time from the bucket and update the database
Future<void> useTime(ObjectId slotIdentifier, int deltaTime, BuildContext context, String childId) async {
    final bucket = await getTokenBucket(slotIdentifier);
    bucket.updateRemainingTime(); // Refill tokens based on time passed

    if (bucket.tokens > 0) {
      bucket.tokens -= deltaTime; // Deduct used time in seconds
      await updateRemainingTime(slotIdentifier, bucket);
    } else {
      bucket.lockDevice(context, childId); // Lock device when tokens are zero
    }
}

  // Reset the slot to the max time
  Future<void> resetSlot(ObjectId slotIdentifier) async {
    final bucket = TokenBucket(capacity: maxTime, refillRate: refillRate);
    bucket.resetRemainingTime(); // Reset to full time (max tokens)
    await updateRemainingTime(slotIdentifier, bucket);
  }

  // Sync time slots with remaining time for a specific child
  Future<void> syncTimeSlotsWithRemainingTime(dynamic childId) async {
    final timeManagementDoc = await timeManagementCollection.findOne(where.eq('child_id', childId));
    String logMessages = "[REMAINING TIME SERVICE] Update started.\n";

    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];

      for (var timeSlot in timeSlots) {
        final slotIdentifier = timeSlot['slot_identifier'];
        final int allowedTime = timeSlot['allowed_time'] ?? 3600;
        final String endTime = timeSlot['end_time'];

        final DateTime now = DateTime.now();
        final DateTime slotEndTime = DateTime.parse(endTime);

        if (now.isAfter(slotEndTime)) {
          await zeroOutRemainingTime(slotIdentifier);
          logMessages += "[REMAINING TIME SERVICE] Slot $slotIdentifier zeroed out as time passed.\n";
        } else {
          await remainingTimeCollection.update(
            where.eq('slot_identifier', ObjectId.fromHexString(slotIdentifier)),
            modify
                .set('remaining_time', allowedTime)
                .set('timestamp', DateTime.now()),
            upsert: true,
          );
          logMessages += "[REMAINING TIME SERVICE] Slot $slotIdentifier synced with remaining time $allowedTime.\n";

          // Check if remaining time is greater than 0, if yes, unlock the device
          if (allowedTime > 0) {
            final bucket = await getTokenBucket(slotIdentifier);
            if (bucket.tokens == 0) {
              bucket.unlockDevice(); // Unlock device when time is replenished
            }
          }
        }
      }

      logMessages += "[REMAINING TIME SERVICE] Update completed for child: $childId\n";
    } else {
      throw Exception("No time slots found for child: $childId");
    }
  }

  // Function to zero out remaining time if the slot end time has passed
  Future<void> zeroOutRemainingTime(dynamic slotIdentifier) async {
    final bucket = await getTokenBucket(slotIdentifier);

    if (bucket.getRemainingTime() > 0) {
      bucket.tokens = 0;
      await updateRemainingTime(slotIdentifier, bucket);
    }
  }
}*/

/*gana man guro ni e update lang kay e try ug implement sa device
import 'package:mongo_dart/mongo_dart.dart';
import '../algorithm/tokenbucket.dart';
import 'package:logger/logger.dart'; // Import the Logger package

class RemainingTimeService {
  final DbCollection remainingTimeCollection;
  final DbCollection timeManagementCollection;
  final Logger _logger = Logger(); // Initialize a logger instance

  RemainingTimeService({
    required this.remainingTimeCollection,
    required this.timeManagementCollection,
  });

  // Fetch the TokenBucket for a specific slot
  Future<TokenBucket> getTokenBucket(dynamic slotIdentifier) async {
    final document = await remainingTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) {
      throw Exception("Slot not found for identifier: $slotIdentifier.");
    }

    final int remainingTime = document['remaining_time'] ?? 0;
    final DateTime lastRefill = document['timestamp']?.toDateTime() ?? DateTime.now();

    final TokenBucket bucket = TokenBucket(capacity: remainingTime, refillRate: 1);
    bucket.tokens = remainingTime;
    bucket.lastRefill = lastRefill;

    final DateTime now = DateTime.now();
    final int minutesPassed = now.difference(lastRefill).inMinutes;

    if (minutesPassed > 0) {
      bucket.tokens = remainingTime - minutesPassed; // Adjust tokens manually based on time passed
      bucket.lastRefill = now;

      if (bucket.tokens < 0) {
        bucket.tokens = 0; // Ensure tokens don't go below zero
      }
    }

    return bucket;
  }

  // Update the remaining time in the database
  Future<void> updateRemainingTime(dynamic slotIdentifier, TokenBucket bucket) async {
    await remainingTimeCollection.update(
      where.eq('slot_identifier', slotIdentifier),
      modify
          .set('remaining_time', bucket.getRemainingTime())
          .set('timestamp', DateTime.now()),
    );
  }

  // Sync time slots with remaining time for a specific child
  Future<void> syncTimeSlotsWithRemainingTime(dynamic childId) async {
    final timeManagementDoc = await timeManagementCollection.findOne(where.eq('child_id', childId));
    String logMessages = "[REMAINING TIME SERVICE] Update started.\n";

    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];

      for (var timeSlot in timeSlots) {
        final slotIdentifier = timeSlot['slot_identifier'];
        final int allowedTime = timeSlot['allowed_time'] ?? 3600;
        final String endTime = timeSlot['end_time'];

        final DateTime now = DateTime.now();
        final DateTime slotEndTime = DateTime.parse(endTime);

        if (now.isAfter(slotEndTime)) {
          await zeroOutRemainingTime(slotIdentifier);
          logMessages += "[REMAINING TIME SERVICE] Slot $slotIdentifier zeroed out as time passed.\n";
        } else {
          await remainingTimeCollection.update(
            where.eq('slot_identifier', ObjectId.fromHexString(slotIdentifier)),
            modify
                .set('remaining_time', allowedTime)
                .set('timestamp', DateTime.now()),
            upsert: true,
          );
          logMessages += "[REMAINING TIME SERVICE] Slot $slotIdentifier synced with remaining time $allowedTime.\n";
        }
      }

      logMessages += "[REMAINING TIME SERVICE] Update completed for child: $childId\n";
      _logger.i(logMessages);  // Log all collected messages using Logger
    } else {
      throw Exception("No time slots found for child: $childId");
    }
  }

  // Function to zero out remaining time if the slot end time has passed
  Future<void> zeroOutRemainingTime(dynamic slotIdentifier) async {
    final bucket = await getTokenBucket(slotIdentifier);

    if (bucket.getRemainingTime() > 0) {
      bucket.tokens = 0;
      await updateRemainingTime(slotIdentifier, bucket);
    }
  }
}
*/