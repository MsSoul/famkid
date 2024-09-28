// filename: services/time_management_service.dart
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
