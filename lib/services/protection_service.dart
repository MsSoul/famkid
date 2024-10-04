//filename:services/protection_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For decoding JSON responses
import '../services/device_control.dart';  // DeviceControl for lock/unlock functionality
import 'config.dart'; // Import Config to use baseUrl
import '../lock_screen.dart';  // Import lock screen for PIN verification
import '../services/app_management_service.dart';

class ProtectionService {
  // Create an instance of AppManagementService
  final AppManagementService appManagementService = AppManagementService();

  // Call the backend API to check the remaining time for the child and lock/unlock the device and apps
  Future<void> applyProtection(String childId, BuildContext context) async {
    try {
      // Log the request details
      debugPrint('Fetching protection for childId: $childId');

      // Make the API request to get the remaining time for the child
      final response = await http.get(Uri.parse('${Config.baseUrl}/api/protection/$childId'));

      // Log the status code and response
      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final int remainingTime = data['remaining_time'] ?? 0;

        // Log the remaining time for debugging purposes
        debugPrint('Remaining time for child $childId: $remainingTime');

        // If remaining time is greater than zero, unlock the device and unblock apps
        if (remainingTime > 0) {
          debugPrint('Time remaining. Unlock the device and unblock apps.');

          // Unlock the device
          bool isAdminEnabled = await DeviceControl.isAdminEnabled();
          if (isAdminEnabled) {
            await DeviceControl.unlockDevice();
            debugPrint('Device unlocked successfully.');
          } else {
            debugPrint('Device Admin is not enabled. Requesting to enable.');
            await DeviceControl.enableAdmin();  // Request user to enable Device Admin
            if (!context.mounted) return;
            _showErrorDialog(context, 'Device Admin is not enabled. Please enable it to unlock the device.');
          }

          // Unblock apps
          await _unblockApps(childId);

          // Show success dialog after unlocking device and apps
          if (!context.mounted) return;
          _showProtectionDialog(context, 'Device and Apps Unlocked!', 'Proceed', childId, false);
        } 
        // If no remaining time, lock the device and block apps
        else {
          debugPrint('Locking the device and blocking apps as remaining time is zero.');

          // Lock the device
          bool isAdminEnabled = await DeviceControl.isAdminEnabled();
          if (isAdminEnabled) {
            await DeviceControl.lockDevice();
            debugPrint('Device locked successfully.');
          } else {
            debugPrint('Device Admin is not enabled. Requesting to enable.');
            await DeviceControl.enableAdmin(); // Request user to enable Device Admin
            if (!context.mounted) return;
            _showErrorDialog(context, 'Device Admin is not enabled. Please enable it to lock the device.');
          }

          // Block apps
          await _blockApps(childId);

          // Navigate to LockScreen after locking the device and apps
          if (!context.mounted) return;
          _navigateToLockScreen(context, childId);
        }
      } else if (response.statusCode == 404) {
        // Handle the case when no remaining time is found
        debugPrint('No remaining time found for childId $childId.');
        if (!context.mounted) return;
        _showErrorDialog(context, 'No remaining time found for this child.');
      } else {
        // Log any non-200 response
        debugPrint('Failed to fetch remaining time. Status code: ${response.statusCode}');
        throw Exception('Failed to fetch remaining time from server. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Log any error encountered
      debugPrint('Error applying protection for childId $childId: $e');
      if (!context.mounted) return;
      _showErrorDialog(context, e.toString());  // Show error dialog in case of exception
    }
  }

  // Method to block apps using App Management
  Future<void> _blockApps(String childId) async {
    try {
      // Fetch apps and apply blocking based on the childId
      final apps = await appManagementService.fetchApps(childId);
      await appManagementService.applyUserAppSettings(apps); // Block user apps
      await appManagementService.applyPinLockForSystemApps(apps['pin_locked_system_apps'] ?? []); // PIN lock system apps
      debugPrint('Apps blocked successfully.');
    } catch (e) {
      debugPrint('Error blocking apps: $e');
    }
  }

  // Method to unblock apps using App Management
  Future<void> _unblockApps(String childId) async {
    try {
      // Fetch apps and apply unblocking based on the childId
      final apps = await appManagementService.fetchApps(childId);
      await appManagementService.applyUserAppSettings(apps); // Unblock user apps
      await appManagementService.applyPinLockForSystemApps(apps['pin_locked_system_apps'] ?? []); // Ensure system apps are PIN locked if necessary
      debugPrint('Apps unblocked successfully.');
    } catch (e) {
      debugPrint('Error unblocking apps: $e');
    }
  }

  // Navigate to the LockScreen for PIN entry
  void _navigateToLockScreen(BuildContext context, String childId) {
    debugPrint('Navigating to LockScreen for childId: $childId');
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LockScreen(childId: childId)),
    ).then((_) {
      debugPrint('Navigation to LockScreen completed.');
    }).catchError((error) {
      debugPrint('Error navigating to LockScreen: $error');
    });
  }

  // Show a dialog to confirm whether to unlock or lock the device
  void _showProtectionDialog(BuildContext context, String title, String buttonText, String childId, bool isLocked) {
  final theme = Theme.of(context); // Fetch the current theme
  final appBarColor = theme.appBarTheme.backgroundColor ?? Colors.green; // Use AppBar color
  final buttonStyle = theme.elevatedButtonTheme.style; // Use the theme's elevated button style

  showDialog(
    context: context,
    barrierDismissible: false, // Prevent closing by tapping outside the dialog
    builder: (context) {
      return AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor, // Use theme's background color
        shape: RoundedRectangleBorder(
          side: BorderSide(color: appBarColor, width: 2.0), // Add a border with the AppBar color
          borderRadius: BorderRadius.circular(20.0),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color ?? Colors.red, // Use theme's text color, default to red
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                
                // If the device is locked, navigate to the LockScreen for PIN entry
                if (isLocked) {
                  _navigateToLockScreen(context, childId);
                } else {
                  // If the device is unlocked, print the action and continue
                  debugPrint('Proceed to use the unlocked device.');
                }
              },
              style: buttonStyle, // Use the theme's elevated button style
              child: Text(
                buttonText,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color ?? Colors.white, // Use theme's text color or default to white
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  // Show an error dialog when something goes wrong
  void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: true,  // Allow closing by tapping outside the dialog
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Error occurred!',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                errorMessage,
                style: const TextStyle(fontSize: 16.0),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/*e modify kay e  interagte na abg app management
// filename: services/protection_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For decoding JSON responses
import '../services/device_control.dart';  // DeviceControl for lock/unlock functionality
import 'config.dart'; // Import Config to use baseUrl
import '../lock_screen.dart';  // Import lock screen for PIN verification

class ProtectionService {
  // Call the backend API to check the remaining time for the child and lock/unlock the device
  Future<void> applyProtection(String childId, BuildContext context) async {
    try {
      // Log the request details
      debugPrint('Fetching protection for childId: $childId');

      // Make the API request to get the remaining time for the child
      final response = await http.get(Uri.parse('${Config.baseUrl}/api/protection/$childId'));

      // Log the status code and response
      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final int remainingTime = data['remaining_time'] ?? 0;

        // Log the remaining time for debugging purposes
        debugPrint('Remaining time for child $childId: $remainingTime');

        // If remaining time is greater than zero, unlock the device
        if (remainingTime > 0) {
          debugPrint('Time remaining. Unlock the device.');

          // Check if Device Admin is enabled before unlocking
          bool isAdminEnabled = await DeviceControl.isAdminEnabled();
          if (isAdminEnabled) {
            await DeviceControl.unlockDevice();
            _showProtectionDialog(context, 'Device Unlocked!', 'Proceed to Lock Again', childId, false);
          } else {
            debugPrint('Device Admin is not enabled. Requesting to enable.');
            await DeviceControl.enableAdmin();  // Request user to enable Device Admin
            _showErrorDialog(context, 'Device Admin is not enabled. Please enable it to unlock the device.');
          }
        } 
        // If no remaining time, lock the device
        else {
          debugPrint('Locking the device as remaining time is zero.');
          
          // Make sure admin is enabled before locking
          bool isAdminEnabled = await DeviceControl.isAdminEnabled();
          if (isAdminEnabled) {
            await DeviceControl.lockDevice();
            debugPrint('Device locked successfully.');
            _navigateToLockScreen(context, childId);  // Navigate to LockScreen after locking the device
          } else {
            debugPrint('Device Admin is not enabled. Requesting to enable.');
            await DeviceControl.enableAdmin(); // Request user to enable Device Admin
            _showErrorDialog(context, 'Device Admin is not enabled. Please enable it to lock the device.');
          }
        }
      } else if (response.statusCode == 404) {
        // Handle the case when no remaining time is found
        debugPrint('No remaining time found for childId $childId.');
        _showErrorDialog(context, 'No remaining time found for this child.');
      } else {
        // Log any non-200 response
        debugPrint('Failed to fetch remaining time. Status code: ${response.statusCode}');
        throw Exception('Failed to fetch remaining time from server. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Log any error encountered
      debugPrint('Error applying protection for childId $childId: $e');
      _showErrorDialog(context, e.toString());  // Show error dialog in case of exception
    }
  }

  // Navigate to the LockScreen for PIN entry
  void _navigateToLockScreen(BuildContext context, String childId) {
    debugPrint('Navigating to LockScreen for childId: $childId');
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LockScreen(childId: childId)),
    ).then((_) {
      debugPrint('Navigation to LockScreen completed.');
    }).catchError((error) {
      debugPrint('Error navigating to LockScreen: $error');
    });
  }

  // Show a dialog to confirm whether to unlock or lock the device
  void _showProtectionDialog(BuildContext context, String title, String buttonText, String childId, bool isLocked) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside the dialog
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  
                  // If the device is locked, navigate to the LockScreen for PIN entry
                  if (isLocked) {
                    _navigateToLockScreen(context, childId);
                  } else {
                    // If the device is unlocked, print the action and continue
                    debugPrint('Proceed to use the unlocked device.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Show an error dialog when something goes wrong
  void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: true,  // Allow closing by tapping outside the dialog
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Error occurred!',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                errorMessage,
                style: const TextStyle(fontSize: 16.0),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}*/