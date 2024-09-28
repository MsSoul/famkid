// filename: close.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For closing the app
import 'services/app_management_service.dart'; // Import your service

class CloseScreen extends StatefulWidget {
  final String childId;

  const CloseScreen({super.key, required this.childId});

  @override
  CloseScreenState createState() => CloseScreenState();
}

class CloseScreenState extends State<CloseScreen> {
  final AppManagementService appService = AppManagementService();

  @override
  void initState() {
    super.initState();
    // Automatically navigate to the close confirmation screen when the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showProtectionSuccessDialog();
    });
  }

  // Display a success dialog after protection is applied
  void _showProtectionSuccessDialog() {
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
              const Text(
                'Device successfully protected!',
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  // Fetch and block apps before closing
                  await appService.fetchAndApplyAppSettings(widget.childId);  // Use widget.childId
                  SystemNavigator.pop(); // Close the app UI without terminating background services
                },
                style: Theme.of(context).elevatedButtonTheme.style, // Use the theme's elevated button style
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.black,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Empty build method since the dialog will automatically be shown on init
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Show loading spinner while waiting for dialog
      ),
    );
  }
}


/*wla pa ni child id sa fetchbloakapps
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For closing the app
import 'services/app_management_service.dart'; // Import your service

class CloseScreen extends StatefulWidget {
  final String childId;

  const CloseScreen({super.key, required this.childId});

  @override
  CloseScreenState createState() => CloseScreenState();
}

class CloseScreenState extends State<CloseScreen> {
  final AppManagementService appService = AppManagementService();

  @override
  void initState() {
    super.initState();
    // Automatically navigate to the close confirmation screen when the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showProtectionSuccessDialog();
    });
  }

  // Display a success dialog after protection is applied
  void _showProtectionSuccessDialog() {
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
              const Text(
                'Device successfully protected!',
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  // Fetch and block apps before closing
                  await appService.fetchAndBlockApps(childId);
                  SystemNavigator.pop(); // Close the app UI without terminating background services
                },
                style: Theme.of(context).elevatedButtonTheme.style, // Use the theme's elevated button style
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.black,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Empty build method since the dialog will automatically be shown on init
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Show loading spinner while waiting for dialog
      ),
    );
  }
}
*/

/*
// filename: close.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // For closing the app
import '../services/pin_service.dart';  // Import PinService to save PIN
import 'pin_screen.dart';  // Import PinScreen for entering the PIN

final PinService pinService = PinService();  // Initialize PinService

class CloseScreen extends StatefulWidget {
  final String childId;

  const CloseScreen({super.key, required this.childId});

  @override
  CloseScreenState createState() => CloseScreenState();
}

class CloseScreenState extends State<CloseScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate directly to PinScreen when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToPinScreen();
    });
  }

  Future<void> _navigateToPinScreen() async {
    // Navigate directly to the PinScreen and pass the necessary childId
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PinScreen(
          childId: widget.childId,
          onPinEntered: _removeProtectionAndCloseApp,  // Handle PIN submission
        ),
      ),
    );
  }

  Future<void> _removeProtectionAndCloseApp(String enteredPin) async {
    try {
      // Call the service to save the PIN
      await pinService.savePin(widget.childId, enteredPin);  // Save the entered PIN

      // Once the PIN is saved, close the app
      SystemNavigator.pop();  // This will close the app
    } catch (error) {
      // Show an error dialog if saving fails
      showErrorDialog(context, 'Failed to save PIN. Please try again.');
    }
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);  // Close dialog
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[200]),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Empty build method since we immediately navigate to PinScreen
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),  // Show loading spinner while navigating
      ),
    );
  }
}
*/