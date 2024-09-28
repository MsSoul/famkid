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
}