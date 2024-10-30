// filename: ../algorithm/tokenbucket.dart
import 'package:flutter/material.dart';  
import 'package:logger/logger.dart';
import '../lock_screen.dart'; 

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
      // Add refill tokens based on elapsed time
      int refillTokens = (elapsedTime * refillRate).toInt();

      // Add tokens but do not exceed capacity
      tokens = (tokens + refillTokens).clamp(0, capacity);

      // Update the last refill time to now
      lastRefill = now;

      // Log the token refill process
      logger.i("Tokens refilled by $refillTokens. Current tokens: $tokens");

      // If tokens are greater than zero, unlock the device
      if (tokens > 0) {
        unlockDevice(); // Unlock device when there are tokens
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
    tokens = capacity; // Reset to full capacity
    lastRefill = DateTime.now(); // Reset last refill time
    logger.i("Tokens reset to capacity: $capacity");
    unlockDevice(); // Reset also unlocks the device if it was locked
  }

  // Method to deduct tokens (for example, usage time in seconds)
  void deductTime(int deltaTime, BuildContext context, String childId) {
    updateRemainingTime(); // Ensure the tokens are up to date

    if (tokens > 0) {
      tokens = (tokens - deltaTime).clamp(0, capacity); // Deduct time
      logger.i("Time deducted: $deltaTime seconds. Remaining tokens: $tokens");

      // If tokens become zero, lock the device and show the lock screen
      if (tokens == 0) {
        lockDevice(context, childId); // Pass context and childId
      }
    }
  }

  // Logic to lock the device and show the LockScreen
  void lockDevice(BuildContext context, String childId) {
    logger.i("Device is locked. Showing PIN lock screen.");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LockScreen(childId: childId), // Pass the dynamic child ID
      ),
    );
  }

  // Logic to unlock the device or allow access
  void unlockDevice() {
    if (tokens > 0) { // Check if there are remaining tokens
      logger.i("Device or app unlocked.");
      // Implement your device/app unlocking logic here
    } else {
      logger.w("Cannot unlock device: no remaining time.");
    }
  }

  // Method to check if the device should be locked (S(t) == 0)
  bool shouldLockDevice() {
    updateRemainingTime(); // Ensure time is updated before checking
    return tokens == 0;
  }
}

