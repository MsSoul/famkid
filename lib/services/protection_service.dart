//filename:services/protection_service.dart
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
}

/*
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
          await DeviceControl.enableAdmin(); // Ensure admin is enabled
          await DeviceControl.lockDevice();   // Lock the device

          _showProtectionDialog(context, 'Device Locked!', 'Proceed to Unlock', childId, true);
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LockScreen(childId: childId)),
                    );
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



/*working ni dagdagn lang ug function na unlocking
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For decoding JSON responses
import '../services/device_control.dart';  // DeviceControl for lock/unlock functionality
import 'config.dart'; // Import Config to use baseUrl
import '../lock_screen.dart';

class ProtectionService {
  // Call the backend API to check the remaining time for the child and lock/unlock the device
  Future<void> applyProtection(String childId, BuildContext context) async {
    try {
      // Log the childId and API URL for debugging purposes
      debugPrint('[PROTECTION SERVICE] Fetching protection for childId: $childId from ${Config.baseUrl}/api/protection/$childId');

      // Make the HTTP GET request
      final response = await http.get(Uri.parse('${Config.baseUrl}/api/protection/$childId'));

      // Log the status code and response body for debugging
      debugPrint('[PROTECTION SERVICE] Status Code: ${response.statusCode}');
      debugPrint('[PROTECTION SERVICE] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Parse the response and check the remaining time
        final Map<String, dynamic> data = jsonDecode(response.body);
        final int remainingTime = data['remaining_time'] ?? 0;

        // Log the remaining time for debugging
        debugPrint('[PROTECTION SERVICE] Remaining time for childId $childId: $remainingTime seconds');

        // Check if remaining time is greater than zero
        if (remainingTime > 0) {
          // Log the unlock action
          debugPrint('[PROTECTION SERVICE] Unlocking device as remaining time is available.');
          await DeviceControl.unlockDevice();  // Unlock the device

          // Show success dialog for unlocked device
          _showProtectionDialog(context, 'Device Unlocked!', 'Proceed to Lock Again', childId);
        } else {
          // Log the lock action
          debugPrint('[PROTECTION SERVICE] Locking device as remaining time is zero.');
          await DeviceControl.enableAdmin();  // Enable Device Admin
          await DeviceControl.lockDevice();  // Lock the device

          // Show success dialog for locked device
          _showProtectionDialog(context, 'Device Locked!', 'Proceed to Unlock', childId);
        }
      } else if (response.statusCode == 404) {
        // Handle the case where no remaining time is found
        debugPrint('[PROTECTION SERVICE] No remaining time found for childId $childId. Showing error.');
        _showErrorDialog(context, 'No remaining time found for this child.');
      } else {
        // Log any non-200 response
        debugPrint('[PROTECTION SERVICE] Failed to fetch protection for childId $childId. Status code: ${response.statusCode}');
        throw Exception('Failed to fetch remaining time from server. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Log the error message
      debugPrint('[PROTECTION SERVICE] Error applying protection for childId $childId: $e');
      _showErrorDialog(context, e.toString()); // Show error dialog if an exception occurs
    }
  }

  // Show dialog after device locking/unlocking
  // Dynamic dialog to show different states based on locking/unlocking
  void _showProtectionDialog(BuildContext context, String title, String buttonText, String childId) {
    showDialog(
      context: context,
      barrierDismissible: false,  // Prevent closing by tapping outside the dialog
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
                  Navigator.pop(context);  // Close the dialog
                  // Navigate to the LockScreen where the user can enter their PIN
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LockScreen(childId: childId)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,  // Customize button color
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

  // Optional: Show an error dialog if protection fails
  void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: true,  // Allow closing the dialog by tapping outside
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
                  Navigator.pop(context);  // Close the dialog
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

*/
/*import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For decoding JSON responses
import '../services/device_control.dart';  // DeviceControl for lock/unlock functionality
import 'config.dart'; // Import Config to use baseUrl
import '../lock_screen.dart';  // Import lock screen for PIN verification

class ProtectionService {
  // Call the backend API to check the remaining time for the child and lock/unlock the device
  Future<void> applyProtection(String childId, BuildContext context) async {
    try {
      // Log the request details
      debugPrint('Sending request for childId: $childId');

      // Make the API request without the deviceTime
  final response = await http.get(
  Uri.parse('${Config.baseUrl}/protection/$childId'),
);
      // Handle the response based on status code
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final int remainingTime = data['remaining_time'] ?? 0;

        // Log the remaining time for debugging
        debugPrint('Remaining time for child $childId: $remainingTime');

        // Unlock the device if there's remaining time
        if (remainingTime > 0) {
          debugPrint('Unlocking device for child $childId');
          await DeviceControl.unlockDevice();
        } 
        // Lock the device and show the lock dialog if no remaining time
        else {
          debugPrint('Locking device for child $childId');
          await DeviceControl.enableAdmin();
          await DeviceControl.lockDevice();

          // Show lock screen dialog for PIN verification
          _showLockDialog(context, childId);
        }
      } else {
        // Log the status code and error response
        debugPrint('Failed to fetch remaining time from server. Status code: ${response.statusCode}');
        throw Exception('Failed to fetch remaining time from server. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error applying protection: $e');
      _showErrorDialog(context, e.toString());  // Show error dialog if fetching remaining time fails
    }
  }

  // Show a dialog when the device is locked, allowing the user to proceed to unlock the device with a PIN
  void _showLockDialog(BuildContext context, String childId) {
    showDialog(
      context: context,
      barrierDismissible: false,  // Prevent closing by tapping outside the dialog
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
                'DEVICE IS LOCKED!',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              /*const Text(
                'Tap the button below to unlock the device.',
                style: TextStyle(fontSize: 18.0),
                textAlign: TextAlign.center,
              ),*/
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);  // Close the dialog
                  // Navigate to the LockScreen where the user can enter their PIN
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LockScreen(childId: childId)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,  // Customize button color
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text(
                  'Proceed to Unlock',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Optional: Show an error dialog if protection fails
  void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: true,  // Allow closing the dialog by tapping outside
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
                  Navigator.pop(context);  // Close the dialog
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
*/
/*import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For decoding JSON responses
import '../services/device_control.dart';  // DeviceControl for lock/unlock functionality
import 'config.dart'; // Import Config to use baseUrl
import '../lock_screen.dart';  // Import lock screen for PIN verification

class ProtectionService {
  // Call the backend API to check the remaining time for the child and lock/unlock the device
  Future<void> applyProtection(String childId, BuildContext context) async {
    try {
      // Get the current device time
      final String deviceTime = DateTime.now().toIso8601String();

      // Make the API request, sending device time
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/protection/$childId?deviceTime=$deviceTime'),
      );

      // Handle the response based on status code
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final int remainingTime = data['remaining_time'] ?? 0;

        // Unlock the device if there's remaining time
        if (remainingTime > 0) {
          await DeviceControl.unlockDevice();
        } 
        // Lock the device and show the lock dialog if no remaining time
        else {
          await DeviceControl.enableAdmin();
          await DeviceControl.lockDevice();

          // Show lock screen dialog for PIN verification
          _showLockDialog(context, childId);
        }
      } else {
        throw Exception('Failed to fetch remaining time from server. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error applying protection: $e');
    }
  }

  // Show a dialog when the device is locked, allowing the user to proceed to unlock the device with a PIN
  void _showLockDialog(BuildContext context, String childId) {
    showDialog(
      context: context,
      barrierDismissible: false,  // Prevent closing by tapping outside the dialog
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
                'DEVICE IS LOCKED!',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Tap the button below to unlock the device.',
                style: TextStyle(fontSize: 18.0),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);  // Close the dialog
                  // Navigate to the LockScreen where the user can enter their PIN
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LockScreen(childId: childId)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,  // Customize button color
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text(
                  'Proceed to Unlock',
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

*/

/*import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For decoding JSON responses
import '../services/device_control.dart';  // DeviceControl for lock/unlock functionality
import 'config.dart'; // Import Config to use baseUrl

class ProtectionService {
  // Call the backend API to check the remaining time for the child and lock/unlock the device
  Future<void> applyProtection(String childId, BuildContext context) async {
    try {
      // Log the childId and API URL for debugging purposes
      debugPrint('Fetching protection for childId: $childId from ${Config.baseUrl}/protection/$childId');

      // Make the HTTP GET request
      final response = await http.get(Uri.parse('${Config.baseUrl}/api/protection/$childId'));


      // Log the status code and response body for debugging
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Parse the response and check the remaining time
        final Map<String, dynamic> data = jsonDecode(response.body);
        final int remainingTime = data['remaining_time'] ?? 0;

        // Log the remaining time for debugging
        debugPrint('Remaining time for childId $childId: $remainingTime seconds');

        // Check if remaining time is greater than zero
        if (remainingTime > 0) {
          // Log the unlock action
          debugPrint('Unlocking device as remaining time is available.');
          await DeviceControl.unlockDevice();  // Unlock the device
        } else {
          // Log the lock action
          debugPrint('Locking device as remaining time is zero.');
          await DeviceControl.enableAdmin();  // Enable Device Admin
          await DeviceControl.lockDevice();  // Lock the device
        }

        // Show the success dialog regardless of whether it's locked or unlocked
        _showProtectionSuccessDialog(context);
      } else {
        // Log any non-200 response
        debugPrint('Failed to fetch protection for childId $childId. Status code: ${response.statusCode}');
        throw Exception('Failed to fetch remaining time from server. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Log the error message
      debugPrint('Error applying protection for childId $childId: $e');
    }
  }

  // Show success dialog after device locking/unlocking
  void _showProtectionSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                'Device successfully protected!',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: Theme.of(context).elevatedButtonTheme.style,
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16.0, color: Colors.black),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
*/