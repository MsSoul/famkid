import 'package:flutter/material.dart';
import 'services/api_service.dart'; 
import 'design/theme.dart'; 

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  TextEditingController emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); 
  ApiService apiService = ApiService(); 
  bool _isLoading = false; 

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); 
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Scaffold(
      appBar: customAppBar(context, 'Forgot Password'), 
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView( // Added to allow scrolling if needed
          child: Column(
            children: [
              const SizedBox(height: 50), // Spacer to push content upwards
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align items to the start (left)
                  children: [
                    Text(
                      'Enter your email to reset your password',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontFamily: theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia', 
                        color: textColor, 
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator()) 
                        : ElevatedButton(
                            onPressed: _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.elevatedButtonTheme.style?.backgroundColor?.resolve({}), 
                            ), 
                            child: const Text('Reset Password'),
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

  Future<void> _resetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true; 
      });

      final email = emailController.text;
      try {
        var result = await apiService.resetPassword(email); 
        if (result) {
          _showDialog('Password reset link sent to $email');
        } else {
          _showDialog('Error: Unable to send reset link');
        }
      } catch (e) {
        _showDialog('An error occurred. Please try again.');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
