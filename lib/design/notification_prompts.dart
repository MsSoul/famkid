// filename: design/notification_prompts.dart
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:logger/logger.dart'; // Import Logger
import '../protection_screen.dart'; // Import the ProtectionScreen
import 'package:flutter_spinkit/flutter_spinkit.dart'; // For loading spinner

final Logger logger = Logger(); // Create a Logger instance

void showSuccessPrompt(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white, // White background
        title: const Text('Congratulations!'),
        content: const Text('Welcome to Famie, you successfully created an account. Proceed to login.'),
        actionsAlignment: MainAxisAlignment.center, // Center the button
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[200], // Button color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            ),
            child: const Text('Log In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Georgia')),
          ),
        ],
      );
    },
  );
}

void showConnectionSuccessPrompt(BuildContext context) {
  // First show the green loading spinner
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent dismissing the loading dialog
    builder: (context) {
      return const Center(
        child: SpinKitFadingCircle(
          color: Color(0xFF388E3C), // Green color for the loading spinner
          size: 50.0,
        ),
      );
    },
  );

  // Simulate a short delay (e.g., for any network operation)
  Future.delayed(const Duration(seconds: 2), () {
    // Close the loading spinner dialog after 2 seconds
    Navigator.of(context).pop();

    // Show the success image and Next button after the spinner disappears
    showDialog(
      context: context,
      builder: (context) {
        logger.i('Displaying success.png after spinner');
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/success.png',
                width: 200,
                height: 200,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                  return const Text('Failed to load image');
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Successfully Connected!',
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Proceed to ProtectionScreen
              ElevatedButton(
                onPressed: () {
                  // Directly navigate to the ProtectionScreen without the second spinner
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const ProtectionScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  });
}



// Error Notification Prompt
void showErrorPrompt(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white, // White background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: const Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}


/*
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:logger/logger.dart'; // Import Logger
import '../protection_screen.dart'; // Import the ProtectionScreen

final Logger logger = Logger(); // Create a Logger instance

void showSuccessPrompt(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white, // White background
        title: const Text('Congratulations!'),
        content: const Text('Welcome to Famie, you successfully created an account. Proceed to login.'),
        actionsAlignment: MainAxisAlignment.center, // Center the button
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[200], // Button color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            ),
            child: const Text('Log In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Georgia')),
          ),
        ],
      );
    },
  );
}

void showConnectionSuccessPrompt(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      logger.i('Attempting to load success.png');
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/success.png',
              width: 200,
              height: 200,
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                return const Text('Failed to load image');
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Successfully Connected!',
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
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const ProtectionScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
              ),
              child: const Text(
                'Next',
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.white,
                  fontFamily: 'Georgia',
                ),
              ),
            ),
          ],
        ),
      );
    },
  );*/
