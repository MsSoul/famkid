import 'dart:async';
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
