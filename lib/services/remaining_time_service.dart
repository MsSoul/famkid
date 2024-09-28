// filename: services/remaining_time_service.dart
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

/*
import 'package:mongo_dart/mongo_dart.dart';
import '../algorithm/tokenbucket.dart'; // Assuming you have a tokenbucket algorithm

class RemainingTimeService {
  final DbCollection remainingTimeCollection;
  final DbCollection timeManagementCollection;

  RemainingTimeService({
    required this.remainingTimeCollection,
    required this.timeManagementCollection,
  });

  // Fetch the TokenBucket for a specific slot
  Future<TokenBucket> getTokenBucket(dynamic slotIdentifier) async {
    final document = await remainingTimeCollection.findOne(where.eq('slot_identifier', slotIdentifier));
    if (document == null) {
      throw Exception("Slot not found.");
    }

    final int remainingTime = document['remaining_time'] ?? 0;
    final DateTime lastRefill = document['timestamp']?.toDateTime() ?? DateTime.now();

    final TokenBucket bucket = TokenBucket(capacity: remainingTime, refillRate: 1);
    bucket.tokens = remainingTime; // Set the current remaining time
    bucket.lastRefill = lastRefill; // Set the last refill time

    // Check if time has passed and update tokens accordingly
    final DateTime now = DateTime.now();
    final int minutesPassed = now.difference(lastRefill).inMinutes;

    if (minutesPassed > 0) {
      bucket.tokens -= minutesPassed; // Decrement by the number of minutes passed
      bucket.lastRefill = now; // Update last refill to now

      if (bucket.tokens < 0) {
        bucket.tokens = 0; // Ensure tokens do not go below zero
      }
    }

    return bucket;
  }

  // Update the remaining time in the database
  Future<void> updateRemainingTime(dynamic slotIdentifier, TokenBucket bucket) async {
    await remainingTimeCollection.update(
      where.eq('slot_identifier', slotIdentifier),
      modify.set('remaining_time', bucket.getRemainingTime()).set('timestamp', DateTime.now()),
    );
  }

  // Sync time slots with remaining time
  Future<void> syncTimeSlotsWithRemainingTime(dynamic childId) async {
    final timeManagementDoc = await timeManagementCollection.findOne(where.eq('child_id', childId));

    if (timeManagementDoc != null && timeManagementDoc['time_slots'] != null) {
      final List<dynamic> timeSlots = timeManagementDoc['time_slots'];

      for (var timeSlot in timeSlots) {
        final slotIdentifier = ObjectId.fromHexString(timeSlot['slot_identifier']);
        final int allowedTime = timeSlot['allowed_time'] ?? 3600;
        final String endTime = timeSlot['end_time'];

        final DateTime now = DateTime.now();
        final DateTime slotEndTime = DateTime.parse(endTime);

        if (now.isAfter(slotEndTime)) {
          await zeroOutRemainingTime(slotIdentifier);
        } else {
          await remainingTimeCollection.update(
            where.eq('slot_identifier', slotIdentifier),
            modify.set('remaining_time', allowedTime).set('timestamp', DateTime.now()),
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