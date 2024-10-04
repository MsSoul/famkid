// filename: close.dart
// filename: close.dart
import 'package:flutter/material.dart';
import '../services/protection_service.dart'; // Import the ProtectionService
import '../design/theme.dart'; // Import your custom theme for consistent styling

class CloseScreen extends StatefulWidget {
  final String childId;

  const CloseScreen({super.key, required this.childId});

  @override
  CloseScreenState createState() => CloseScreenState();
}

class CloseScreenState extends State<CloseScreen> {
  final ProtectionService _protectionService = ProtectionService(); // Initialize ProtectionService
  bool _isLoading = false; // Manage loading state for the button

  // Trigger protection logic when the close button is pressed
  Future<void> _applyProtection() async {
    setState(() {
      _isLoading = true;  // Start loading
    });

    try {
      // Log that protection is being applied
      debugPrint('Applying protection for childId: ${widget.childId}');
      
      // Trigger protection logic (lock/unlock the device)
      await _protectionService.applyProtection(widget.childId, context);
      
    } catch (error) {
      debugPrint('Error applying protection: $error');
      _showErrorDialog(context, error.toString());
    } finally {
      // Ensure loading is stopped in both success and failure cases
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading
        });
      }
    }
  }

  // Show an error dialog if protection fails
  void _showErrorDialog(BuildContext context, String errorMessage) {
    final theme = Theme.of(context); // Fetch theme data
    final appBarColor = theme.appBarTheme.backgroundColor ?? Colors.red; // Use AppBar color
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black; // Theme text color
    final fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia'; // Theme font style

    showDialog(
      context: context,
      barrierDismissible: true,  // Allow closing the dialog by tapping outside
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor, // Use theme background color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Error occurred!',
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: appBarColor, // Use AppBar color for the title
                  fontFamily: fontFamily, // Use theme's font style
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                errorMessage,
                style: TextStyle(
                  fontSize: 16.0,
                  color: textColor, // Use theme's text color
                  fontFamily: fontFamily, // Use theme's font style
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);  // Close the dialog
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appBarColor, // Use AppBar color
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Fetch theme data
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black; // Theme text color
    final fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia'; // Theme font style

    return Scaffold(
      appBar: customAppBar(context, 'Device Protection'), // Use your custom app bar
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Device successfully protected!',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily, // Use theme's font style
                color: textColor, // Use theme's text color
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading
                  ? null // Disable button when loading
                  : () async {
                      await _applyProtection(); // Apply protection when clicked
                    },
              style: theme.elevatedButtonTheme.style, // Use the theme's elevated button style
              child: _isLoading
                  ? const CircularProgressIndicator() // Show spinner when loading
                  : Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16.0,
                        color: textColor, // Use theme's text color
                        fontFamily: fontFamily, // Use theme's font style
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/*import 'package:flutter/material.dart';
import '../services/protection_service.dart'; // Import the ProtectionService
import '../design/theme.dart'; // Import your custom theme for consistent styling

class CloseScreen extends StatefulWidget {
  final String childId;

  const CloseScreen({super.key, required this.childId});

  @override
  CloseScreenState createState() => CloseScreenState();
}

class CloseScreenState extends State<CloseScreen> {
  final ProtectionService _protectionService = ProtectionService(); // Initialize ProtectionService
  bool _isLoading = false; // Manage loading state for the button

  // Trigger protection logic when the close button is pressed
  Future<void> _applyProtection() async {
  setState(() {
    _isLoading = true;  // Start loading
  });

  try {
    // Log that protection is being applied
    debugPrint('Applying protection for childId: ${widget.childId}');
    
    // Trigger protection logic (lock/unlock the device)
    await _protectionService.applyProtection(widget.childId, context);
    
  } catch (error) {
    debugPrint('Error applying protection: $error');
    _showErrorDialog(context, error.toString());
  } finally {
    // Ensure loading is stopped in both success and failure cases
    if (mounted) {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }
}

  // Show an error dialog if protection fails
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Device Protection'), // Use your custom app bar
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Device successfully protected!',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading
                  ? null // Disable button when loading
                  : () async {
                      await _applyProtection(); // Apply protection when clicked
                    },
              style: Theme.of(context).elevatedButtonTheme.style, // Use the theme's elevated button style
              child: _isLoading
                  ? const CircularProgressIndicator() // Show spinner when loading
                  : const Text(
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
      ),
    );
  }
}*/

/*gana na ning lock device ang problema kay loading lang dli mag gawas ang prompt
import 'package:flutter/material.dart'; // Flutter imports
import '../services/protection_service.dart'; // Import the ProtectionService
import '../design/theme.dart'; // Import your custom theme for consistent styling
import 'lock_screen.dart';

class CloseScreen extends StatefulWidget {
  final String childId;

  const CloseScreen({super.key, required this.childId});

  @override
  CloseScreenState createState() => CloseScreenState();
}

class CloseScreenState extends State<CloseScreen> {
  final ProtectionService _protectionService = ProtectionService(); // Initialize ProtectionService
  bool _isLoading = false; // Manage loading state for the button

  // Trigger protection logic when the close button is pressed
  Future<void> _applyProtection() async {
    setState(() {
      _isLoading = true;  // Start loading
    });

    try {
      // Log that protection is being applied
      debugPrint('Applying protection for childId: ${widget.childId}');
      
      // Trigger protection logic (lock/unlock the device)
      await _protectionService.applyProtection(widget.childId, context);
    } catch (error) {
      debugPrint('Error applying protection: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading
        });
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Device Protection'), // Use your custom app bar
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Device successfully protected!',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading
                  ? null // Disable button when loading
                  : () async {
                      await _applyProtection(); // Apply protection when clicked
                      // Show the dynamic dialog after protection is applied
                      _showProtectionDialog(
                        context,
                        'DEVICE IS LOCKED!',
                        'Proceed to Unlock',
                        widget.childId,
                      );
                    },
              style: Theme.of(context).elevatedButtonTheme.style, // Use the theme's elevated button style
              child: _isLoading
                  ? const CircularProgressIndicator() // Show spinner when loading
                  : const Text(
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
      ),
    );
  }
}

*/
/*try lang ang naa sa taas
import 'package:flutter/material.dart'; 
import '../services/protection_service.dart'; // Import the ProtectionService
import '../design/theme.dart'; // Import your custom theme for consistent styling

class CloseScreen extends StatefulWidget {
  final String childId;

  const CloseScreen({super.key, required this.childId});

  @override
  CloseScreenState createState() => CloseScreenState();
}

class CloseScreenState extends State<CloseScreen> {
  final ProtectionService _protectionService = ProtectionService(); // Initialize ProtectionService
  bool _isLoading = false; // Manage loading state for the button

  // Trigger protection logic when the close button is pressed
  Future<void> _applyProtection() async {
    setState(() {
      _isLoading = true;  // Start loading
    });

    try {
      // Trigger protection logic (lock/unlock the device)
      await _protectionService.applyProtection(widget.childId, context);
    } catch (error) {
      debugPrint('Error applying protection: $error');
    } finally {
      setState(() {
        _isLoading = false; // Stop loading once protection logic is done
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Device Protection'), // Use your custom app bar
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Device successfully protected!',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading
                  ? null // Disable button when loading
                  : () async {
                      await _applyProtection(); // Apply protection when clicked
                      Navigator.pop(context); // Close the screen after locking/unlocking
                    },
              style: Theme.of(context).elevatedButtonTheme.style, // Use the theme's elevated button style
              child: _isLoading
                  ? const CircularProgressIndicator() // Show spinner when loading
                  : const Text(
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
      ),
    );
  }
}

*/
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