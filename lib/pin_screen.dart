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
                  'REMINDER: This PIN will be used to lock your child\'s device. You will need it to deactivate protection.',
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
}

/*
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/pin_service.dart'; // Import PinService to verify the PIN

class PinScreen extends StatefulWidget {
  final String childId;
  final Future<void> Function(String) onPinEntered;

  const PinScreen({super.key, required this.childId, required this.onPinEntered});

  @override
  PinScreenState createState() => PinScreenState();
}

class PinScreenState extends State<PinScreen> {
  final TextEditingController _pinController = TextEditingController(); // Controller to capture PIN input
  bool _isLoading = false;
  bool _isPinError = false; // To show error when PIN is invalid
  final PinService pinService = PinService(); // Initialize PinService
  final Logger logger = Logger();

  // Function to handle PIN entry and validation
  Future<void> _handlePinEntry() async {
    setState(() {
      _isLoading = true;
      _isPinError = false;
    });

    String enteredPin = _pinController.text;

    // Validate if the entered PIN is 4 digits
    if (!RegExp(r'^\d{4}$').hasMatch(enteredPin)) {
      setState(() {
        _isPinError = true; // Show PIN error if invalid format
        _isLoading = false;
      });
      return;
    }

    try {
      // Call the callback from CloseScreen to save the PIN
      await widget.onPinEntered(enteredPin);
      logger.d("PIN successfully handled");
    } catch (error) {
      setState(() {
        _isPinError = true; // Show error if there's an issue with saving the PIN
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Enter a 4-digit PIN',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true, // Hide the PIN as it is entered
                maxLength: 4, // Limit input to 4 digits
                decoration: InputDecoration(
                  labelText: 'PIN',
                  border: const OutlineInputBorder(),
                  errorText: _isPinError ? 'Invalid PIN. Must be 4 digits.' : null,
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator() // Show loading indicator while processing
                  : ElevatedButton(
                      onPressed: _handlePinEntry, // Handle PIN entry
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[200]),
                      child: const Text('Submit'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
*/