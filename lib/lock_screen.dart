//filename:lock screen// filename: lock_screen.dart
// filename: lock_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/pin_service.dart';
import '../services/device_control.dart';
import '../design/theme.dart';

final Logger logger = Logger();  // Initialize Logger
final PinService pinService = PinService();  // Initialize PinService

class LockScreen extends StatefulWidget {
  final String childId;
  final bool isAppLocked; // New parameter to determine if it's for an app lock
  final String? appName; // Optional: Pass app name if applicable

  const LockScreen({super.key, required this.childId, this.isAppLocked = false, this.appName});

  @override
  LockScreenState createState() => LockScreenState();
}

class LockScreenState extends State<LockScreen> {
  final TextEditingController pin1Controller = TextEditingController();
  final TextEditingController pin2Controller = TextEditingController();
  final TextEditingController pin3Controller = TextEditingController();
  final TextEditingController pin4Controller = TextEditingController();

  final FocusNode pin1FocusNode = FocusNode();
  final FocusNode pin2FocusNode = FocusNode();
  final FocusNode pin3FocusNode = FocusNode();
  final FocusNode pin4FocusNode = FocusNode();

  String _enteredPin = '';  // Store entered PIN
  bool _isLoading = false;

  @override
  void dispose() {
    pin1Controller.dispose();
    pin2Controller.dispose();
    pin3Controller.dispose();
    pin4Controller.dispose();
    pin1FocusNode.dispose();
    pin2FocusNode.dispose();
    pin3FocusNode.dispose();
    pin4FocusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    // Combine the entered PIN from the stored variable
    String fullPin = _enteredPin;
    logger.i('Entered PIN: $fullPin');  // Log the entered PIN

    // Ensure PIN is exactly 4 digits long and only contains numbers
    if (fullPin.length == 4 && RegExp(r'^\d{4}$').hasMatch(fullPin)) {
      setState(() {
        _isLoading = true;  // Show loading spinner
      });

      try {
        logger.i('Attempting to verify the PIN');
        bool isValid = await pinService.verifyPin(widget.childId, fullPin);  // Verify the PIN using the service
        if (isValid) {
          logger.i('PIN verified successfully');

          // Unlock the device or app by passing the entered PIN to the native Android code
          await DeviceControl.unlockWithPin(fullPin);

          // Close the lock screen
          if (mounted) {
            Navigator.pop(context);  // Exit the lock screen if PIN is correct
          }
        } else {
          logger.w('Incorrect PIN entered');
          _showErrorDialog('Incorrect PIN. Please try again.');
        }
      } catch (error) {
        logger.e('Error while verifying PIN: $error');
        _showErrorDialog('Failed to verify PIN. Please try again.');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;  // Stop the loading spinner
          });
        }
      }
    } else {
      _showErrorDialog('Please enter a valid 4-digit PIN.');
    }
  }

  void _showErrorDialog(String message) {
    // Show the error dialog
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
    ).then((_) {
      // Clear all PIN controllers after the dialog is dismissed
      pin1Controller.clear();
      pin2Controller.clear();
      pin3Controller.clear();
      pin4Controller.clear();
      _enteredPin = '';  // Clear the stored PIN
    });
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor = Theme.of(context).appBarTheme.backgroundColor;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: customAppBar(context, 'Enter PIN'),  // Custom app bar
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),

              // Add the warning icon above the text
              Icon(
                Icons.warning_rounded,
                color: appBarColor,  // Match the color to the app bar
                size: 80.0,  // Adjust the size as needed
              ),

              const SizedBox(height: 20),

              // Conditional text based on whether an app or device is locked
              widget.isAppLocked
                  ? Text(
                      'This App is Locked!',
                      style: textTheme.bodyLarge?.copyWith(fontSize: 28.0, fontWeight: FontWeight.bold, color: appBarColor),
                      textAlign: TextAlign.center,
                    )
                  : Text(
                      'This Device is Locked!',
                      style: textTheme.bodyLarge?.copyWith(fontSize: 28.0, fontWeight: FontWeight.bold, color: appBarColor),
                      textAlign: TextAlign.center,
                    ),

              const SizedBox(height: 20),

              // Modified Enter PIN text
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: textTheme.bodyLarge?.copyWith(fontSize: 20.0),  // Use theme's text style
                  children: <TextSpan>[
                    const TextSpan(text: 'Enter '),  // Normal text
                    TextSpan(
                      text: 'PIN ',  // PIN styled with custom app bar color and bold
                      style: TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: widget.isAppLocked ? 'to unlock the app.' : 'to unlock the device.'),  // Conditional text
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPinBox(pin1Controller, pin1FocusNode, pin2FocusNode, appBarColor, 0),
                  _buildPinBox(pin2Controller, pin2FocusNode, pin3FocusNode, appBarColor, 1),
                  _buildPinBox(pin3Controller, pin3FocusNode, pin4FocusNode, appBarColor, 2),
                  _buildPinBox(pin4Controller, pin4FocusNode, null, appBarColor, 3),
                ],
              ),
              const SizedBox(height: 20),

              _isLoading
                  ? const CircularProgressIndicator()  // Show spinner while loading
                  : ElevatedButton(
                      onPressed: () {
                        logger.i('Unlock button clicked');
                        _verifyPin();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}),  // Use button color from theme
                      ),
                      child: const Text('Unlock'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to build a PIN input box
  Widget _buildPinBox(TextEditingController controller, FocusNode currentNode, FocusNode? nextNode, Color? pinColor, int index) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: controller,
        focusNode: currentNode,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 28.0,
          fontWeight: FontWeight.bold,
          color: pinColor,  // Set PIN text color as same as app bar color
        ),
        decoration: const InputDecoration(
          counterText: '',
        ),
        onChanged: (value) {
          if (value.isNotEmpty && RegExp(r'^\d$').hasMatch(value)) {
            logger.i('Entered digit: $value');

            // Add the entered digit to the stored PIN
            if (index < _enteredPin.length) {
              _enteredPin = _enteredPin.substring(0, index) + value;
            } else {
              _enteredPin += value;
            }

            // Automatically move to the next field or verify the PIN when all fields are filled
            if (nextNode != null) {
              FocusScope.of(context).requestFocus(nextNode);  // Move to the next field
            } else {
              currentNode.unfocus();  // Unfocus if the last digit
              _verifyPin();  // Automatically verify when the last digit is entered
            }

            // Mask the input after 1.5 seconds
            Timer(const Duration(milliseconds: 1500), () {
              controller.text = "*";  // Mask the input with "*"
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            });
          }
        },
        onSubmitted: (value) {
          if (nextNode == null) {
            _verifyPin();
          }
        },
      ),
    );
  }
}


/*
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/pin_service.dart';
import '../services/device_control.dart';
import '../design/theme.dart';

final Logger logger = Logger();  // Initialize Logger
final PinService pinService = PinService();  // Initialize PinService

class LockScreen extends StatefulWidget {
  final String childId;

  const LockScreen({super.key, required this.childId});

  @override
  LockScreenState createState() => LockScreenState();
}

class LockScreenState extends State<LockScreen> {
  final TextEditingController pin1Controller = TextEditingController();
  final TextEditingController pin2Controller = TextEditingController();
  final TextEditingController pin3Controller = TextEditingController();
  final TextEditingController pin4Controller = TextEditingController();

  final FocusNode pin1FocusNode = FocusNode();
  final FocusNode pin2FocusNode = FocusNode();
  final FocusNode pin3FocusNode = FocusNode();
  final FocusNode pin4FocusNode = FocusNode();

  bool _isLoading = false;

  @override
  void dispose() {
    pin1Controller.dispose();
    pin2Controller.dispose();
    pin3Controller.dispose();
    pin4Controller.dispose();
    pin1FocusNode.dispose();
    pin2FocusNode.dispose();
    pin3FocusNode.dispose();
    pin4FocusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    // Capture the entered PIN from all 4 fields
    String fullPin = pin1Controller.text + pin2Controller.text + pin3Controller.text + pin4Controller.text;
    logger.i('Entered PIN: $fullPin');  // Log the entered PIN before masking

    // Ensure PIN is exactly 4 digits long and only contains numbers
    if (fullPin.length == 4 && RegExp(r'^\d{4}$').hasMatch(fullPin)) {
      setState(() {
        _isLoading = true;  // Show loading spinner
      });

      try {
        logger.i('Attempting to verify the PIN');
        bool isValid = await pinService.verifyPin(widget.childId, fullPin);  // Verify the PIN using the service
        if (isValid) {
          logger.i('PIN verified successfully');

          // Unlock the device by passing the entered PIN to the native Android code
          await DeviceControl.unlockWithPin(fullPin);

          // Close the lock screen
          if (mounted) {
            Navigator.pop(context);  // Exit the lock screen if PIN is correct
          }
        } else {
          logger.w('Incorrect PIN entered');
          _showErrorDialog('Incorrect PIN. Please try again.');
        }
      } catch (error) {
        logger.e('Error while verifying PIN: $error');
        _showErrorDialog('Failed to verify PIN. Please try again.');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;  // Stop the loading spinner
          });
        }
      }
    } else {
      _showErrorDialog('Please enter a valid 4-digit PIN.');
    }
  }

  void _showErrorDialog(String message) {
    // Show the error dialog
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
    ).then((_) {
      // Clear all PIN controllers after the dialog is dismissed
      pin1Controller.clear();
      pin2Controller.clear();
      pin3Controller.clear();
      pin4Controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor = Theme.of(context).appBarTheme.backgroundColor;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: customAppBar(context, 'Enter PIN'),  // Custom app bar
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),

              // Add the warning icon above the text
              Icon(
                Icons.warning_rounded,
                color: appBarColor,  // Match the color to the app bar
                size: 80.0,  // Adjust the size as needed
              ),

              const SizedBox(height: 20),

              // Split "This Device is Locked!" into separate styles
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: textTheme.bodyLarge?.copyWith(fontSize: 28.0, fontWeight: FontWeight.bold),
                  children: <TextSpan>[
                    const TextSpan(text: 'This Device is ', style: TextStyle(color: Colors.black)),  // Black text
                    TextSpan(
                      text: 'Locked!',  // Use custom app bar color and make it bold
                      style: TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Modified Enter PIN text with "PIN" styled
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: textTheme.bodyLarge?.copyWith(fontSize: 20.0),  // Use theme's text style
                  children: <TextSpan>[
                    const TextSpan(text: 'Enter '),  // Normal text
                    TextSpan(
                      text: 'PIN ',  // PIN styled with custom app bar color and bold
                      style: TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: 'to unlock the device.'),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPinBox(pin1Controller, pin1FocusNode, pin2FocusNode, appBarColor),
                  _buildPinBox(pin2Controller, pin2FocusNode, pin3FocusNode, appBarColor),
                  _buildPinBox(pin3Controller, pin3FocusNode, pin4FocusNode, appBarColor),
                  _buildPinBox(pin4Controller, pin4FocusNode, null, appBarColor),
                ],
              ),
              const SizedBox(height: 20),

              _isLoading
                  ? const CircularProgressIndicator()  // Show spinner while loading
                  : ElevatedButton(
                      onPressed: () {
                        logger.i('Unlock button clicked');
                        _verifyPin();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}),  // Use button color from theme
                      ),
                      child: const Text('Unlock'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to build a PIN input box
  Widget _buildPinBox(TextEditingController controller, FocusNode currentNode, FocusNode? nextNode, Color? pinColor) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: controller,
        focusNode: currentNode,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 28.0,
          fontWeight: FontWeight.bold,
          color: pinColor,  // Set PIN text color as same as app bar color
        ),
        decoration: const InputDecoration(
          counterText: '',
        ),
        onChanged: (value) {
          if (value.isNotEmpty && RegExp(r'^\d$').hasMatch(value)) {
            // Log the entered digit
            logger.i('Entered digit: $value');  // Log the individual digit before masking
            
            if (nextNode != null) {
              FocusScope.of(context).requestFocus(nextNode);  // Move to the next field
            } else {
              currentNode.unfocus();  // Unfocus if the last digit
              _verifyPin();  // Automatically verify when the last digit is entered
            }

            // Mask the input after capturing the digit
            Timer(const Duration(milliseconds: 1500), () {
              controller.text = "*";  // Mask the input with "*" after a 1.5-second delay
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            });
          }
        },
        onSubmitted: (value) {
          if (nextNode == null) {
            _verifyPin(); 
          }
        },
      ),
    );
  }
}
*/

/*import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';  // Import the logger package
import '../services/pin_service.dart';  // Pin service for verifying the pin
import '../design/theme.dart';  // Assuming custom app bar and other designs

final Logger logger = Logger();  // Initialize Logger
final PinService pinService = PinService();  // Initialize PinService

class LockScreen extends StatefulWidget {
  final String childId;

  const LockScreen({super.key, required this.childId});

  @override
  LockScreenState createState() => LockScreenState();
}

class LockScreenState extends State<LockScreen> {
  final TextEditingController pin1Controller = TextEditingController();
  final TextEditingController pin2Controller = TextEditingController();
  final TextEditingController pin3Controller = TextEditingController();
  final TextEditingController pin4Controller = TextEditingController();

  final FocusNode pin1FocusNode = FocusNode();
  final FocusNode pin2FocusNode = FocusNode();
  final FocusNode pin3FocusNode = FocusNode();
  final FocusNode pin4FocusNode = FocusNode();

  bool _isLoading = false;
  List<String> enteredPin = ["", "", "", ""];  // List to store the entered pin digits

  @override
  void dispose() {
    pin1Controller.dispose();
    pin2Controller.dispose();
    pin3Controller.dispose();
    pin4Controller.dispose();
    pin1FocusNode.dispose();
    pin2FocusNode.dispose();
    pin3FocusNode.dispose();
    pin4FocusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    String fullPin = enteredPin.join();
    logger.i('Entered PIN: $fullPin');

    if (fullPin.length == 4 && RegExp(r'^\d{4}$').hasMatch(fullPin)) {
      setState(() {
        _isLoading = true;  // Show loading spinner
      });

      try {
        logger.i('Attempting to verify the PIN');
        bool isValid = await pinService.verifyPin(widget.childId, fullPin);  // Verify the PIN using the service
        if (isValid) {
          logger.i('PIN verified successfully');

          // Unlock the device (or close the lock screen)
          Navigator.pop(context);  // Exit the lock screen if PIN is correct
        } else {
          logger.w('Incorrect PIN entered');
          _showErrorDialog('Incorrect PIN. Please try again.');
        }
      } catch (error) {
        logger.e('Error while verifying PIN: $error');
        _showErrorDialog('Failed to verify PIN. Please try again.');
      } finally {
        setState(() {
          _isLoading = false;  // Make sure this gets reset to show the button again
        });
      }
    } else {
      _showErrorDialog('Please enter a valid 4-digit PIN.');
    }
  }

  void _showErrorDialog(String message) {
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
    return Scaffold(
      appBar: customAppBar(context, 'Enter PIN'),  // Use your custom app bar
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              const Text(
                'Enter PIN to unlock the device.',
                style: TextStyle(fontSize: 26.0, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPinBox(pin1Controller, pin1FocusNode, pin2FocusNode, 0),
                  _buildPinBox(pin2Controller, pin2FocusNode, pin3FocusNode, 1),
                  _buildPinBox(pin3Controller, pin3FocusNode, pin4FocusNode, 2),
                  _buildPinBox(pin4Controller, pin4FocusNode, null, 3),
                ],
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        logger.i('Unlock button clicked');
                        _verifyPin();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[200]),
                      child: const Text('Unlock'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinBox(TextEditingController controller, FocusNode currentNode, FocusNode? nextNode, int index) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: controller,
        focusNode: currentNode,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28.0),
        decoration: const InputDecoration(
          counterText: '',
        ),
        onChanged: (value) {
          if (value.isNotEmpty && RegExp(r'^\d$').hasMatch(value)) {
            enteredPin[index] = value;  // Store the digit in the correct index

            if (nextNode != null) {
              FocusScope.of(context).requestFocus(nextNode);
            } else {
              currentNode.unfocus();  // Unfocus if last digit
            }

            Timer(const Duration(milliseconds: 500), () {
              controller.text = "*";  // Mask the input after a short delay
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            });
          }
        },
        onSubmitted: (value) {
          if (nextNode == null) {
            _verifyPin();  // Submit when the last field is entered
          }
        },
      ),
    );
  }
}
*/