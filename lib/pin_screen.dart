// filename: pin_screen.dart
// filename: pin_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';  // Import the logger package
import '../services/pin_service.dart';  // Pin service for saving the pin
import '../design/theme.dart';  // Assuming custom app bar and other designs
import 'close.dart';

final Logger logger = Logger();  // Initialize Logger
final PinService pinService = PinService();  // Initialize PinService

class PinScreen extends StatefulWidget {
  final String childId;
  final Future<void> Function(String pin) onPinEntered;

  const PinScreen({super.key, required this.childId, required this.onPinEntered});

  @override
  PinScreenState createState() => PinScreenState();
}

class PinScreenState extends State<PinScreen> {
  final TextEditingController pin1Controller = TextEditingController();
  final TextEditingController pin2Controller = TextEditingController();
  final TextEditingController pin3Controller = TextEditingController();
  final TextEditingController pin4Controller = TextEditingController();

  final FocusNode pin1FocusNode = FocusNode();
  final FocusNode pin2FocusNode = FocusNode();
  final FocusNode pin3FocusNode = FocusNode();
  final FocusNode pin4FocusNode = FocusNode();

  bool _isLoading = false;
  List<String> realPin = ["", "", "", ""];  // List to store the pin digits

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

  Future<void> _submitPin() async {
    String fullPin = realPin.join();
    logger.i('Entered PIN: $fullPin');

    if (fullPin.length == 4 && RegExp(r'^\d{4}$').hasMatch(fullPin)) {
      setState(() {
        _isLoading = true;  // Show loading spinner
      });

      try {
        logger.i('Attempting to save the PIN');
        await pinService.savePin(widget.childId, fullPin);  // Save the PIN using the service
        logger.i('PIN saved successfully');

        // Navigate to CloseScreen after successful PIN save
        if (mounted) {  // Check if the widget is still mounted before navigating
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CloseScreen(childId: widget.childId),
            ),
          );
        }
      } catch (error) {
        logger.e('Error while saving PIN: $error');
        _showErrorDialog('Failed to save PIN. Please try again.');
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
    final theme = Theme.of(context);  // Get the current theme
    final appBarColor = theme.appBarTheme.backgroundColor ?? Colors.green;  // Use AppBar color
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;  // Get theme's text color
    final fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia';  // Get theme's font style

    return Scaffold(
      appBar: customAppBar(context, 'Set PIN'),  // Use your custom app bar
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              Text(
                'Please enter the PIN to lock the device.',
                style: TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,  // Follow theme font style
                  color: textColor,  // Follow theme text color
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPinBox(pin1Controller, pin1FocusNode, pin2FocusNode, 0, fontFamily, textColor),
                  _buildPinBox(pin2Controller, pin2FocusNode, pin3FocusNode, 1, fontFamily, textColor),
                  _buildPinBox(pin3Controller, pin3FocusNode, pin4FocusNode, 2, fontFamily, textColor),
                  _buildPinBox(pin4Controller, pin4FocusNode, null, 3, fontFamily, textColor),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: appBarColor),  // Use appBar color
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      'REMINDER: \n        This PIN will be used to lock and unlock your child\'s device.',
                      style: TextStyle(
                        fontSize: 16.0,
                        color: appBarColor,  // Use AppBar color
                        fontFamily: fontFamily,  // Use theme font style
                      ),
                      textAlign: TextAlign.left,  // Align text to the left like a paragraph
                    ),
                  )
,
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        logger.i('Save button clicked');
                        _submitPin();
                      },
                      style: theme.elevatedButtonTheme.style,  // Use theme's ElevatedButton style
                      child: Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontFamily: fontFamily,  // Follow theme font style
                          color: theme.textTheme.bodyLarge?.color,  // Follow theme text color
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinBox(
      TextEditingController controller,
      FocusNode currentNode,
      FocusNode? nextNode,
      int index,
      String fontFamily,
      Color textColor) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: controller,
        focusNode: currentNode,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 28.0, fontFamily: fontFamily, color: textColor),  // Use theme's font and color
        decoration: const InputDecoration(
          counterText: '',
        ),
        onChanged: (value) {
          if (value.isNotEmpty && RegExp(r'^\d$').hasMatch(value)) {
            realPin[index] = value;  // Store the digit in the correct index

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
            _submitPin();  // Submit when the last field is entered
          }
        },
      ),
    );
  }
}

/*
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';  // Import the logger package
import '../services/pin_service.dart';  // Pin service for saving the pin
import '../design/theme.dart';  // Assuming custom app bar and other designs
import 'close.dart';

final Logger logger = Logger();  // Initialize Logger
final PinService pinService = PinService();  // Initialize PinService

class PinScreen extends StatefulWidget {
  final String childId;
  final Future<void> Function(String pin) onPinEntered;

  const PinScreen({super.key, required this.childId, required this.onPinEntered});

  @override
  PinScreenState createState() => PinScreenState();
}

class PinScreenState extends State<PinScreen> {
  final TextEditingController pin1Controller = TextEditingController();
  final TextEditingController pin2Controller = TextEditingController();
  final TextEditingController pin3Controller = TextEditingController();
  final TextEditingController pin4Controller = TextEditingController();

  final FocusNode pin1FocusNode = FocusNode();
  final FocusNode pin2FocusNode = FocusNode();
  final FocusNode pin3FocusNode = FocusNode();
  final FocusNode pin4FocusNode = FocusNode();

  bool _isLoading = false;
  List<String> realPin = ["", "", "", ""];  // List to store the pin digits

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

  Future<void> _submitPin() async {
  String fullPin = realPin.join();
  logger.i('Entered PIN: $fullPin');

  if (fullPin.length == 4 && RegExp(r'^\d{4}$').hasMatch(fullPin)) {
    setState(() {
      _isLoading = true;  // Show loading spinner
    });

    try {
      logger.i('Attempting to save the PIN');
      await pinService.savePin(widget.childId, fullPin);  // Save the PIN using the service
      logger.i('PIN saved successfully');

      // Navigate to CloseScreen after successful PIN save
      if (mounted) {  // Check if the widget is still mounted before navigating
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CloseScreen(childId: widget.childId),
          ),
        );
      }
    } catch (error) {
      logger.e('Error while saving PIN: $error');
      _showErrorDialog('Failed to save PIN. Please try again.');
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
      appBar: customAppBar(context, 'Set PIN'),  // Use your custom app bar
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              const Text(
                'Please enter the PIN to lock the device.',
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
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Text(
                  'REMINDER: This PIN will be used to lock and unlock your child\'s device. ',
                  style: TextStyle(fontSize: 16.0, color: Colors.green),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        logger.i('Save button clicked');
                        _submitPin();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[200]),
                      child: const Text('Save'),
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
            realPin[index] = value;  // Store the digit in the correct index

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
            _submitPin();  // Submit when the last field is entered
          }
        },
      ),
    );
  }
}*/