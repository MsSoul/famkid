// filename: ../algorithm/tokenbucket.dart
import 'package:logger/logger.dart';

final Logger logger = Logger();

class TokenBucket {
  final int capacity; // Maximum allowable time in seconds (B)
  int tokens; // Current number of tokens representing the remaining time in seconds (S(t))
  final int refillRate; // Number of tokens added per second (Δt)
  DateTime lastRefill; // Last time the bucket was refilled

  TokenBucket({required this.capacity, required this.refillRate})
      : tokens = capacity, // Initially, the bucket is full
        lastRefill = DateTime.now();

  // Method to update the remaining time based on the elapsed time (Δt)
  void updateRemainingTime() {
    final DateTime now = DateTime.now();
    final int elapsedTime = now.difference(lastRefill).inSeconds; // Δt

    if (elapsedTime > 0) {
      // Deduct the elapsed time from the remaining tokens
      tokens = (tokens - elapsedTime).clamp(0, capacity);
      lastRefill = now;

      // If the tokens become zero, lock the device or restrict app usage
      if (tokens == 0) {
        lockDevice();
      }
    }
  }

  // Method to get the current remaining time (S(t))
  int getRemainingTime() {
    updateRemainingTime(); // Ensure time is updated before returning
    return tokens;
  }

  // Method to reset the remaining time to the maximum capacity (B)
  void resetRemainingTime() {
    tokens = capacity;
    lastRefill = DateTime.now();
  }

  // Method to check if the device should be locked (S(t) == 0)
  bool shouldLockDevice() {
    updateRemainingTime(); // Ensure time is updated before checking
    return tokens == 0;
  }

  // Logic to lock the device or restrict app usage
  void lockDevice() {
    logger.i("Device or app locked.");
    // Implement your locking logic here
  }

  // Logic to unlock the device or allow access
  void unlockDevice() {
    logger.i("Device or app unlocked.");
    // Implement your unlocking logic here
  }
}
