// filename: ../algorithm/time_based_algorithm.dart
import 'package:logger/logger.dart';
import '../algorithm/tokenbucket.dart';

final Logger logger = Logger();

class TimeBasedAlgorithm {
  DateTime lastCheckTime; // The last time the algorithm checked the time
  final TokenBucket tokenBucket; // Token Bucket instance to manage the tokens

  TimeBasedAlgorithm({required this.tokenBucket})
      : lastCheckTime = DateTime.now();

  // Method to check if the current time is midnight
  bool isMidnight(DateTime currentTime) {
    return currentTime.hour == 0 && currentTime.minute == 0;
  }

  // Method to reset the token bucket at midnight
  void resetAtMidnight() {
    final DateTime now = DateTime.now();

    if (isMidnight(now)) {
      // Reset the token bucket at midnight
      tokenBucket.resetRemainingTime();
      logger.i("Time reset at midnight.");
    }
  }

  // Logic to lock the device or restrict access
  void lock() {
    logger.i("Device or app locked.");
    // Implement your locking logic here
  }

  // Logic to unlock the device or allow access
  void unlock() {
    logger.i("Device or app unlocked.");
    // Implement your unlocking logic here
  }

  // Method to apply the time-based logic
  void applyTimeBasedLogic() {
    resetAtMidnight();
    // Additional logic can be implemented here
  }
}
