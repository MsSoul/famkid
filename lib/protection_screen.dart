import 'package:flutter/material.dart';
import '../services/protection_service.dart';
import '../services/app_management_service.dart';
import '../design/theme.dart';
import 'pin_screen.dart';
import 'package:logger/logger.dart';

final ProtectionService protectionService = ProtectionService();
final AppManagementService appManagementService = AppManagementService();
final Logger logger = Logger();

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key});

  @override
  ProtectionScreenState createState() => ProtectionScreenState();
}

class ProtectionScreenState extends State<ProtectionScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Protection Screen'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Do you want to protect this device?',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 50),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: () async {
  setState(() {
    _isLoading = true;
  });

  try {
    // Fetch childId from ProtectionService
    String childId = await protectionService.fetchChildId();

    // Apply app management settings: block/unblock apps for the child
    await appManagementService.fetchAndApplyAppSettings(childId);

    if (!mounted) return;

    // Navigate to the PIN screen after blocking apps
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PinScreen(
          childId: childId,
          onPinEntered: _onPinSaved,
        ),
      ),
    );
  } catch (e) {
    showErrorPrompt(context, e.toString());
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
},
                            style: Theme.of(context).elevatedButtonTheme.style,
                            child: const Text(
                              'Yes',
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> saveBlockedAndAllowedApps(String childId) async {
    try {
      // Fetch apps from app management
      final apps = await appManagementService.fetchApps(childId);
      List<String> blockedApps = apps['blocked'] ?? [];
      List<String> allowedApps = apps['allowed'] ?? [];

      logger.i('Sending blocked and allowed apps: childId=$childId');
      logger.i('Blocked Apps: $blockedApps');
      logger.i('Allowed Apps: $allowedApps');

      // Instead of saving, apply the block/unblock settings to the device
      await appManagementService.applyAppSettings(apps);

      logger.i("Blocked and allowed apps applied successfully.");
    } catch (e) {
      logger.e("Error applying blocked and allowed apps: $e");
    }
  }

  Future<void> _onPinSaved(String pin) async {
    logger.i('PIN saved successfully!');
  }

  @override
  void dispose() {
    protectionService.deactivateProtection();
    super.dispose();
  }

  void showErrorPrompt(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
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
                'Failed to protect device: $errorMessage',
                style: const TextStyle(
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
                  Navigator.of(context).pop();
                },
                style: Theme.of(context).elevatedButtonTheme.style,
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
}

/*app mangement to block apps ni aya
import 'package:flutter/material.dart';
import '../services/protection_service.dart';
import '../services/app_management_service.dart';
import '../design/theme.dart';
import 'pin_screen.dart';
import 'package:logger/logger.dart';

final ProtectionService protectionService = ProtectionService();
final AppManagementService appManagementService = AppManagementService();
final Logger logger = Logger();

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key});

  @override
  ProtectionScreenState createState() => ProtectionScreenState();
}

class ProtectionScreenState extends State<ProtectionScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Protection Screen'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Do you want to protect this device?',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 50),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                _isLoading = true;
                              });

                              try {
                                // Fetch childId from ProtectionService
                                String childId = await protectionService.fetchChildId();
                                
                                // Apply app management settings: block/unblock apps for the child
                                await appManagementService.fetchAndApplyAppSettings(childId);

                                if (!mounted) return; // Ensure the widget is still in the tree

                                // Save the blocked and allowed apps to the backend after applying
                                await saveBlockedAndAllowedApps(childId);

                                // Guard the navigator after async functions
                                if (!mounted) return;

                                // Navigate to PinScreen to set a PIN for protection
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PinScreen(
                                      childId: childId,
                                      onPinEntered: _onPinSaved,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return; // Ensure the widget is still in the tree
                                showErrorPrompt(context, e.toString());
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              }
                            },
                            style: Theme.of(context).elevatedButtonTheme.style,
                            child: const Text(
                              'Yes',
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> saveBlockedAndAllowedApps(String childId) async {
    List<String> blockedApps = ["com.android.chrome", "com.facebook.katana"];
    List<String> allowedApps = ["com.android.camera", "com.android.settings"];

    try {
      logger.i('Sending blocked and allowed apps: childId=$childId');
      logger.i('Blocked Apps: $blockedApps');
      logger.i('Allowed Apps: $allowedApps');

      // Assume this function makes an API call and returns void (no return value needed here)
      await appManagementService.saveBlockedApps(childId, blockedApps, allowedApps);

      logger.i("Blocked and allowed apps saved successfully.");
    } catch (e) {
      logger.e("Error saving blocked and allowed apps: $e");
    }
  }

  Future<void> _onPinSaved(String pin) async {
    logger.i('PIN saved successfully!');
  }

  @override
  void dispose() {
    protectionService.deactivateProtection();
    super.dispose();
  }

  void showErrorPrompt(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
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
                'Failed to protect device: $errorMessage',
                style: const TextStyle(
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
                  Navigator.of(context).pop();
                },
                style: Theme.of(context).elevatedButtonTheme.style,
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
}
*/
/*wla pani update sa blocking apps 
// filename: protection_screen.dart
import 'package:flutter/material.dart';
import '../services/protection_service.dart';
import '../design/theme.dart';
import 'pin_screen.dart'; // Import PinScreen for setting the PIN

final ProtectionService protectionService = ProtectionService();

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key});

  @override
  ProtectionScreenState createState() => ProtectionScreenState();
}

class ProtectionScreenState extends State<ProtectionScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Protection Screen'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Do you want to protect this device?',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 50),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                _isLoading = true;
                              });

                              try {
                                // Fetch childId
                                String childId = await protectionService.fetchChildId();

                                // Activate protection
                                await protectionService.handleProtectionAction(childId);

                                // Navigate to PinScreen to set a PIN for protection
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PinScreen(
                                      childId: childId,
                                      onPinEntered: _onPinSaved, // After PIN is saved
                                    ),
                                  ),
                                );
                              } catch (e) {
                                showErrorPrompt(context, e.toString());
                              } finally {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            },
                            style: Theme.of(context).elevatedButtonTheme.style,
                            child: const Text(
                              'Yes',
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onPinSaved(String pin) async {
    // Here you can perform any additional actions after the PIN is saved.
    print('PIN saved successfully!');
  }

  @override
  void dispose() {
    protectionService.deactivateProtection();
    super.dispose();
  }

  void showErrorPrompt(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
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
                'Failed to protect device: $errorMessage',
                style: const TextStyle(
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
                  Navigator.of(context).pop();
                },
                style: Theme.of(context).elevatedButtonTheme.style,
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
}

*/
/*
import 'package:flutter/material.dart'; 
import '../services/protection_service.dart'; // Import ProtectionService for handling all protection logic
import '../design/theme.dart'; // Custom design for your app, includes `customAppBar`
import 'close.dart'; // Import CloseScreen

final ProtectionService protectionService = ProtectionService(); // Initialize ProtectionService

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key});

  @override
  ProtectionScreenState createState() => ProtectionScreenState();
}

class ProtectionScreenState extends State<ProtectionScreen> {
  bool _isLoading = false; // State to manage loading indicator

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Protection Screen'), // Custom AppBar from your theme
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Do you want to protect this device?',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 50),
                    _isLoading
                        ? const CircularProgressIndicator() // Show loading indicator while waiting for response
                        : ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                _isLoading = true; // Start loading
                              });

                              try {
                                // Fetch childId from the ProtectionService
                                String childId = await protectionService.fetchChildId();

                                // Call protection action with the fetched childId
                                await protectionService.handleProtectionAction(childId);

                                // Pass the childId to the success prompt
                                showProtectionSuccessPrompt(context, childId); 
                              } catch (e) {
                                // Handle errors and show error prompt
                                showErrorPrompt(context, e.toString());
                              } finally {
                                setState(() {
                                  _isLoading = false; // Stop loading after the action is completed
                                });
                              }
                            },
                            style: Theme.of(context).elevatedButtonTheme.style,
                            child: const Text(
                              'Yes',
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    protectionService.deactivateProtection(); // Deactivate protection (stop the Timer) if active
    super.dispose(); // Ensure you call the super dispose method
  }

  // Success dialog when the protection is successful
  void showProtectionSuccessPrompt(BuildContext context, String childId) {
    showDialog(
      context: context,
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
                onPressed: () {
                  Navigator.of(context).pop(); // Close the success dialog
                  
                  // Navigate to the CloseScreen (defined in close.dart) and pass the childId
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CloseScreen(childId: childId),
                    ),
                  );
                },
                style: Theme.of(context).elevatedButtonTheme.style,
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

  // Error dialog in case something goes wrong
  void showErrorPrompt(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
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
                'Failed to protect device: $errorMessage',
                style: const TextStyle(
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
                  Navigator.of(context).pop(); // Close the error dialog
                },
                style: Theme.of(context).elevatedButtonTheme.style,
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
}

*/
/*
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_management_service.dart'; // Import the service
import '../design/theme.dart'; 

final AppManagementService appManagementService = AppManagementService();

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key});

  @override
  ProtectionScreenState createState() => ProtectionScreenState();
}

class ProtectionScreenState extends State<ProtectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Protection Screen'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Do you want to protect this device?',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 50),
                    ElevatedButton(
                      onPressed: () async {
                        await appManagementService.blockAppsAndRunTimeManagement(); // Call the method
                        showProtectionSuccessPrompt(context); // Show success prompt
                      },
                      style: Theme.of(context).elevatedButtonTheme.style,
                      child: const Text(
                        'Yes',
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    appManagementService.closeWebSocket(); // Close the WebSocket connection when the screen is disposed
    super.dispose();
  }

  void showProtectionSuccessPrompt(BuildContext context) {
    showDialog(
      context: context,
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
                onPressed: () {
                  SystemNavigator.pop(); // Close the app
                },
                style: Theme.of(context).elevatedButtonTheme.style,
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
}
*/