// filename: services/time_management_service.dart
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
  Future<void> useTime(ObjectId slotIdentifier, int deltaTime, BuildContext context, String childId) async {
    final bucket = await getTokenBucket(slotIdentifier);
    bucket.updateRemainingTime();

    if (bucket.tokens > 0) {
        bucket.tokens -= deltaTime; // Deduct used time
        await updateRemainingTime(slotIdentifier, bucket);
    } else {
        bucket.lockDevice(context, childId); // Lock the device when tokens reach 0
    }
}

  // Reset the slot to the max time
  Future<void> resetSlot(ObjectId slotIdentifier) async {
    final bucket = TokenBucket(capacity: maxTime, refillRate: refillRate);
    bucket.resetRemainingTime();
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
}

/*woriking pero e update kay  mag implement na sa device
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
    bucket.updateRemainingTime();

    if (bucket.tokens > 0) {
      bucket.tokens -= deltaTime; // Deduct used time
      await updateRemainingTime(slotIdentifier, bucket);
    } else {
      bucket.lockDevice();
    }
  }

  // Reset the slot to the max time
  Future<void> resetSlot(ObjectId slotIdentifier) async {
    final bucket = TokenBucket(capacity: maxTime, refillRate: refillRate);
    bucket.resetRemainingTime();
    await updateRemainingTime(slotIdentifier, bucket);
  }

  // Method to sync time slots from time management to remaining time management
  Future<void> syncTimeSlotsWithRemainingTime(ObjectId childId) async {
    final timeManagementDoc = await timeManagementCollection.findOne(where.eq('child_id', childId));
    
    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];

      for (var timeSlot in timeSlots) {
        final slotIdentifier = timeSlot['slot_identifier'];
        final allowedTime = timeSlot['allowed_time'] ?? maxTime;

        // Initialize the remaining time with the allowed time
        await remainingTimeCollection.update(
          where.eq('slot_identifier', slotIdentifier),
          modify.set('remaining_time', allowedTime).set('timestamp', DateTime.now()),
          upsert: true,
        );
      }
    }
  }
}
*/