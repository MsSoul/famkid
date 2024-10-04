// filename: design/notification_prompts.dart
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:logger/logger.dart'; // Import Logger
import '../protection_screen.dart'; // Import the ProtectionScreen
import 'package:flutter_spinkit/flutter_spinkit.dart'; // For loading spinner

final Logger logger = Logger(); // Create a Logger instance

void showSuccessPrompt(BuildContext context) {
  final theme = Theme.of(context); // Fetch theme
  final appBarColor = theme.appBarTheme.backgroundColor ?? Colors.green; // AppBar color
  final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black; // Theme text color
  final fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia'; // Theme font style

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor, // Background color from theme
        shape: RoundedRectangleBorder(
          side: BorderSide(color: appBarColor, width: 2.0), // Border color same as AppBar
          borderRadius: BorderRadius.circular(15.0), // Rounded corners for the dialog
        ),
        title: Text(
          'Congratulations!',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold, // Make it bold
            fontFamily: fontFamily,
          ),
        ),
        content: Text(
          'Welcome to Famie, you successfully created an account. Proceed to login.',
          style: TextStyle(
            color: textColor, // Use theme's text color
            fontFamily: fontFamily, // Use theme's font style
          ),
        ),
        actionsAlignment: MainAxisAlignment.center, // Center the button
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
            style: theme.elevatedButtonTheme.style, // Use elevated button style from theme
            child: Text(
              'Log In',
              style: TextStyle(
                color: theme.elevatedButtonTheme.style?.foregroundColor?.resolve({}) ?? Colors.black, // Use button text color from theme
                fontWeight: FontWeight.bold, // Bold text
                fontFamily: fontFamily, // Use theme's font style
              ),
            ),
          ),
        ],
      );
    },
  );
}

void showConnectionSuccessPrompt(BuildContext context, String childId) {
  final theme = Theme.of(context); // Fetch theme data
  final appBarColor = theme.appBarTheme.backgroundColor ?? Colors.green; // Use AppBar color
  final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black; // Theme text color
  final fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia'; // Theme font style

  // First show the loading spinner
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent dismissing the loading dialog
    builder: (context) {
      return Center(
        child: SpinKitFadingCircle(
          color: appBarColor, // Spinner color following the AppBar color
          size: 50.0,
        ),
      );
    },
  );

  // Simulate a short delay (e.g., for any network operation)
  Future.delayed(const Duration(seconds: 2), () {
    // Close the loading spinner dialog after 2 seconds
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Show the success icon and Next button after the spinner disappears
    showDialog(
      context: context,
      builder: (context) {
        logger.i('Displaying success check icon after spinner');
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor, // Use the scaffold background color
          shape: RoundedRectangleBorder(
            side: BorderSide(color: appBarColor, width: 2.0), // Add a border with the same color as the AppBar
            borderRadius: BorderRadius.circular(20.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle, // Use the check_circle icon for success
                size: 100,
                color: appBarColor, // Use the AppBar color for the success icon
              ),
              const SizedBox(height: 20),
              Text(
                'Successfully Connected!',
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily, // Use theme's font style
                  color: textColor, // Use theme's text color
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Proceed to ProtectionScreen
              ElevatedButton(
                onPressed: () {
                  // Directly navigate to the ProtectionScreen with childId
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => ProtectionScreen(childId: childId),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
                style: theme.elevatedButtonTheme.style, // Use the elevated button style from the theme
                child: Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: theme.textTheme.bodyLarge?.color, // Use the theme's text color
                    fontFamily: fontFamily, // Use theme's font style
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

void showNoButtonPrompt(BuildContext context) {
  final theme = Theme.of(context); // Fetch theme
  final appBarColor = theme.appBarTheme.backgroundColor ?? Colors.green; // AppBar color
  final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black; // Theme text color
  final fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia'; // Theme font style
  final buttonColor = theme.elevatedButtonTheme.style?.backgroundColor?.resolve({}) ?? Colors.green; // Get elevated button color

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor, // Background color from theme
        shape: RoundedRectangleBorder(
          side: BorderSide(color: appBarColor, width: 2.0), // Border color same as AppBar
          borderRadius: BorderRadius.circular(15.0), // Rounded corners for the dialog
        ),
        title: Text(
          'Are you sure?',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold, // Make it bold
            fontFamily: fontFamily,
          ),
        ),
        content: Text(
          'By continuing, your child\'s device will not be supervised, and you will be logged out. This means no restrictions or monitoring will be in place for your child.',
          style: TextStyle(
            color: textColor, // Use theme's text color
            fontFamily: fontFamily, // Use theme's font style
          ),
        ),
        actionsAlignment: MainAxisAlignment.center, // Center the buttons
        actions: <Widget>[
          // Continue Button (Switched to be the outlined button now)
          OutlinedButton(
            onPressed: () {
              // Log the user out and navigate to the login screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: buttonColor, width: 2.0), // Use elevated button color for border
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0), // Padding
            ),
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 16.0,
                color: buttonColor, // Use elevated button color for text
                fontFamily: fontFamily, // Use theme's font style
              ),
            ),
          ),
          const SizedBox(width: 10), // Add spacing between buttons

          // Go Back Button (Switched to be the elevated button now)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close the prompt without logging out
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor, // Use elevated button color for background
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0), // Padding
            ),
            child: Text(
              'Go Back',
              style: TextStyle(
                fontSize: 16.0,
                color: textColor, // Text color follows theme's text color
                fontFamily: fontFamily, // Use theme's font style
              ),
            ),
          ),
        ],
      );
    },
  );
}

/*----updated na ang taas----*/
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
