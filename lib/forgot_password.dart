import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'design/theme.dart';
import 'main.dart'; // Import the main.dart to access LoginScreen

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
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 50),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              backgroundColor: theme
                                  .elevatedButtonTheme.style?.backgroundColor
                                  ?.resolve({}),
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
    final theme = Theme.of(context);
    final appBarColor = theme.appBarTheme.backgroundColor ?? Colors.blue; // App bar color fallback

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(color: appBarColor, width: 2.0),
          ),
          title: const Text('Forgot Password'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(
                  color: appBarColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); 
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()), // Navigate back to the login screen
                );
              },
            ),
          ],
        );
      },
    );
  }
}
