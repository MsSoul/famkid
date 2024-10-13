// filename: '../services/device_control.dart';// DeviceControl for lock/unlock functionality
import 'package:flutter/services.dart';  // For MethodChannel
import 'package:logger/logger.dart';  // For logging

class DeviceControl {
  static const platform = MethodChannel('com.example.device/control');
  static final Logger logger = Logger();  // Initialize the logger

  // Check if Device Admin is enabled
  static Future<bool> isAdminEnabled() async {
    try {
      final bool isAdminActive = await platform.invokeMethod('isAdminActive');
      logger.i('Device Admin status: $isAdminActive');
      return isAdminActive;
    } on PlatformException catch (e) {
      logger.e('Failed to check Device Admin status: ${e.message}');
      return false;
    }
  }

  // Request the user to enable Device Admin
  static Future<void> enableAdmin() async {
    try {
      await platform.invokeMethod('enableAdmin');
      logger.i('Device Admin enable request sent successfully.');
    } on PlatformException catch (e) {
      logger.e('Failed to enable Device Admin: ${e.message}');
    }
  }

  // Lock the device
  static Future<void> lockDevice() async {
    try {
      await platform.invokeMethod('lockDevice');
      logger.i('Device locked successfully.');
    } on PlatformException catch (e) {
      logger.e('Failed to lock the device: ${e.message}');
    }
  }

  // Unlock the device
  static Future<void> unlockDevice() async {
    try {
      await platform.invokeMethod('unlockDevice');
      logger.i('Device unlocked successfully.');
    } on PlatformException catch (e) {
      logger.e('Failed to unlock the device: ${e.message}');
    }
  }

  // Unlock the device with a PIN
  static Future<void> unlockWithPin(String pin) async {
    try {
      await platform.invokeMethod('unlockWithPin', {"enteredPin": pin});
      logger.i('Device unlocked with PIN successfully.');
    } on PlatformException catch (e) {
      logger.e('Failed to unlock the device with PIN: ${e.message}');
    }
  }
}


/*import 'package:flutter/services.dart';  // For MethodChannel

class DeviceControl {
  static const platform = MethodChannel('com.example.device/control');

  // Check if Device Admin is enabled
  static Future<bool> isAdminEnabled() async {
    try {
      final bool isAdminActive = await platform.invokeMethod('isAdminActive');
      return isAdminActive;
    } on PlatformException catch (e) {
      print("Failed to check Device Admin status: ${e.message}");
      return false;
    }
  }

  // Request the user to enable Device Admin
  static Future<void> enableAdmin() async {
    try {
      await platform.invokeMethod('enableAdmin');
    } on PlatformException catch (e) {
      print("Failed to enable Device Admin: ${e.message}");
    }
  }

  // Lock the device
  static Future<void> lockDevice() async {
    try {
      await platform.invokeMethod('lockDevice');
    } on PlatformException catch (e) {
      print("Failed to lock the device: ${e.message}");
    }
  }

  // Unlock the device
  static Future<void> unlockDevice() async {
    try {
      await platform.invokeMethod('unlockDevice');
    } on PlatformException catch (e) {
      print("Failed to unlock the device: ${e.message}");
    }
  }

  // Unlock the device with a PIN
  static Future<void> unlockWithPin(String pin) async {
    try {
      await platform.invokeMethod('unlockWithPin', {"enteredPin": pin});
    } on PlatformException catch (e) {
      print("Failed to unlock the device with PIN: ${e.message}");
    }
  }
}*/

/*
import 'package:flutter/services.dart';  // For MethodChannel
import 'package:flutter/foundation.dart';  // For debugPrint and other Flutter foundation utilities

class DeviceControl {
  // Define a MethodChannel for device control actions
  static const platform = MethodChannel('com.example.device/control');

  // Request the user to enable Device Admin
  static Future<void> enableAdmin() async {
    try {
      await platform.invokeMethod('enableAdmin');
    } on PlatformException catch (e) {
      debugPrint("Failed to enable Device Admin: ${e.message}");
    }
  }

  // Lock the device
  static Future<void> lockDevice() async {
    try {
      await platform.invokeMethod('lockDevice');
    } on PlatformException catch (e) {
      debugPrint("Failed to lock device: ${e.message}");
    }
  }

  // Unlock the device
  static Future<void> unlockDevice() async {
    try {
      await platform.invokeMethod('unlockDevice');
    } on PlatformException catch (e) {
      debugPrint("Failed to unlock device: ${e.message}");
    }
  }
}
*/