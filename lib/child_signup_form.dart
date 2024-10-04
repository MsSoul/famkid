// filename: child_signup_form.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:logger/logger.dart';
import 'services/api_service.dart';
import 'design/theme.dart';
import 'main.dart';
import 'design/notification_prompts.dart'; // Import the notification prompts
import 'package:intl/intl.dart'; // Import the intl package

class ChildSignupForm extends StatefulWidget {
  const ChildSignupForm({super.key});

  @override
  State<ChildSignupForm> createState() => _ChildSignupFormState();
}

class _ChildSignupFormState extends State<ChildSignupForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController dateOfBirthController = TextEditingController();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode usernameFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode confirmPasswordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _emailError = '';
  String _usernameError = '';
  String _passwordError = '';
  String _confirmPasswordError = '';
  DateTime? _selectedDate;
  String _dateError = '';

  // Helper method to validate email
  bool _isValidEmail(String email) {
    final emailRegExp = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    return emailRegExp.hasMatch(email);
  }

  // Helper method to validate username
  bool _isValidUsername(String username) {
    return username.isNotEmpty;
  }

  // Helper method to validate password
  bool _isValidPassword(String password) {
    return password.isNotEmpty && password.length >= 6;
  }

  void _validateEmail() {
    if (!_isValidEmail(emailController.text)) {
      setState(() {
        _emailError = 'Invalid email format';
      });
    } else {
      setState(() {
        _emailError = '';
      });
    }
  }

  void _validateUsername() {
    if (!_isValidUsername(usernameController.text)) {
      setState(() {
        _usernameError = 'Invalid username';
      });
    } else {
      setState(() {
        _usernameError = '';
      });
    }
  }

  void _validatePassword() {
    if (!_isValidPassword(passwordController.text)) {
      setState(() {
        _passwordError = 'Password must be at least 6 characters';
      });
    } else {
      setState(() {
        _passwordError = '';
      });
    }
  }

  void _validateConfirmPassword() {
    if (confirmPasswordController.text != passwordController.text) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
      });
    } else {
      setState(() {
        _confirmPasswordError = '';
      });
    }
  }

  void _validateDate() {
    if (_selectedDate == null) {
      setState(() {
        _dateError = 'Please select a date';
      });
    } else {
      setState(() {
        _dateError = '';
      });
    }
  }

  void _onSignupPressed() async {
    _validateEmail();
    _validateUsername();
    _validatePassword();
    _validateConfirmPassword();
    _validateDate();

    if (_emailError.isEmpty &&
        _usernameError.isEmpty &&
        _passwordError.isEmpty &&
        _confirmPasswordError.isEmpty &&
        _dateError.isEmpty) {
      try {
        _logger.d('Attempting sign up at ${DateTime.now()}: ${emailController.text}, ${usernameController.text}');
        bool success = await _apiService.signUpChild(
          emailController.text,
          usernameController.text,
          passwordController.text,
          _selectedDate!.day,
          _selectedDate!.month,
          _selectedDate!.year,
        );
        _logger.d('Sign up success: $success');
        if (!mounted) return;
        if (success) {
          _logger.d('Signup successful');
          showSuccessPrompt(context); // Show success prompt
        } else {
          _logger.e('Signup failed');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signup failed')),
          );
        }
      } catch (e) {
        _logger.e('Signup failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signup failed: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
  final theme = Theme.of(context); // Fetch the theme data
  final appBarColor = theme.appBarTheme.backgroundColor ?? Colors.green; // Use AppBar color
  final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black; // Use the theme's text color
  final fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia'; // Use the theme's font family

  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(1900),
    lastDate: DateTime.now(),
    builder: (BuildContext context, Widget? child) {
      return Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: appBarColor, // Use AppBar color for the header
            onPrimary: Colors.white, // Header text color (white)
            onSurface: textColor, // Use theme text color for body text
          ),
          textTheme: TextTheme(
            bodyLarge: TextStyle(color: textColor, fontFamily: fontFamily), // Set text color and font for large body text
            bodyMedium: TextStyle(color: textColor, fontFamily: fontFamily), // Set text color and font for medium body text
          ),
          dialogBackgroundColor: theme.scaffoldBackgroundColor, // Use theme's scaffold background color
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: appBarColor), // Use AppBar color for the border
            ),
          ),
        ),
        child: child!,
      );
    },
  );
  
  if (picked != null && picked != _selectedDate) {
    setState(() {
      _selectedDate = picked;
      dateOfBirthController.text = DateFormat.yMMMMd().format(picked); // Display the selected date with month name
    });
  }
}


  @override
  void initState() {
    super.initState();

    emailFocusNode.addListener(() {
      if (!emailFocusNode.hasFocus) {
        _validateEmail();
      }
    });

    usernameFocusNode.addListener(() {
      if (!usernameFocusNode.hasFocus) {
        _validateUsername();
      }
    });

    passwordFocusNode.addListener(() {
      if (!passwordFocusNode.hasFocus) {
        _validatePassword();
      }
    });

    confirmPasswordFocusNode.addListener(() {
      if (!confirmPasswordFocusNode.hasFocus) {
        _validateConfirmPassword();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get the theme
    final appBarColor = theme.appBarTheme.backgroundColor; // Get the AppBar color
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black; // Get the theme text color
    final fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia'; // Get the theme font style

    return Scaffold(
      appBar: customAppBar(context, 'Sign Up', isLoggedIn: false),
      body: SingleChildScrollView(
        padding: appMargin,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily, // Follow theme font style
                  color: textColor, // Follow theme text color
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                focusNode: emailFocusNode,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  errorText: _emailError.isNotEmpty ? _emailError : null,
                ),
                style: TextStyle(color: textColor, fontFamily: fontFamily), // Set text style to match theme
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: usernameController,
                focusNode: usernameFocusNode,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  errorText: _usernameError.isNotEmpty ? _usernameError : null,
                ),
                style: TextStyle(color: textColor, fontFamily: fontFamily), // Set text style to match theme
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: passwordController,
                focusNode: passwordFocusNode,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  errorText: _passwordError.isNotEmpty ? _passwordError : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: appBarColor, // Use AppBar color for the eye icon
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                style: TextStyle(color: textColor, fontFamily: fontFamily), // Set text style to match theme
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: confirmPasswordController,
                focusNode: confirmPasswordFocusNode,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter your password',
                  errorText: _confirmPasswordError.isNotEmpty ? _confirmPasswordError : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: appBarColor, // Use AppBar color for the eye icon
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                style: TextStyle(color: textColor, fontFamily: fontFamily), // Set text style to match theme
                obscureText: _obscureConfirmPassword,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: dateOfBirthController,
                readOnly: true,
                onTap: () => _selectDate(context),
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  hintText: 'Select your birth date',
                  errorText: _dateError.isNotEmpty ? _dateError : null,
                ),
                style: TextStyle(color: textColor, fontFamily: fontFamily), // Set text style to match theme
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _onSignupPressed,
                style: theme.elevatedButtonTheme.style, // Use the elevated button style from the theme
                child: const Text('Create'),
              ),
              const SizedBox(height: 20),
              RichText(
                text: TextSpan(
                  text: 'Already using Famie? ',
                  style: TextStyle(fontSize: 16.0, color: textColor, fontFamily: fontFamily), // Follow theme text color and font style
                  children: <TextSpan>[
                    TextSpan(
                      text: 'Log in',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        fontSize: 16.0,
                        color: appBarColor, // Use AppBar color for "Log in"
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily, // Follow theme font style
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
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
    emailFocusNode.dispose();
    usernameFocusNode.dispose();
    passwordFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    dateOfBirthController.dispose();
    super.dispose();
  }
}

/*
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:logger/logger.dart';
import 'services/api_service.dart';
import 'design/theme.dart';
import 'main.dart';
import 'design/notification_prompts.dart'; // Import the notification prompts
import 'package:intl/intl.dart'; // Import the intl package

class ChildSignupForm extends StatefulWidget {
  const ChildSignupForm({super.key});

  @override
  State<ChildSignupForm> createState() => _ChildSignupFormState();
}

class _ChildSignupFormState extends State<ChildSignupForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController dateOfBirthController = TextEditingController();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode usernameFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode confirmPasswordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _emailError = '';
  String _usernameError = '';
  String _passwordError = '';
  String _confirmPasswordError = '';
  DateTime? _selectedDate;
  String _dateError = '';

  // Helper method to validate email
  bool _isValidEmail(String email) {
    final emailRegExp = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    return emailRegExp.hasMatch(email);
  }

  // Helper method to validate username
  bool _isValidUsername(String username) {
    return username.isNotEmpty;
  }

  // Helper method to validate password
  bool _isValidPassword(String password) {
    return password.isNotEmpty && password.length >= 6;
  }

  void _validateEmail() {
    if (!_isValidEmail(emailController.text)) {
      setState(() {
        _emailError = 'Invalid email format';
      });
    } else {
      setState(() {
        _emailError = '';
      });
    }
  }

  void _validateUsername() {
    if (!_isValidUsername(usernameController.text)) {
      setState(() {
        _usernameError = 'Invalid username';
      });
    } else {
      setState(() {
        _usernameError = '';
      });
    }
  }

  void _validatePassword() {
    if (!_isValidPassword(passwordController.text)) {
      setState(() {
        _passwordError = 'Password must be at least 6 characters';
      });
    } else {
      setState(() {
        _passwordError = '';
      });
    }
  }

  void _validateConfirmPassword() {
    if (confirmPasswordController.text != passwordController.text) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
      });
    } else {
      setState(() {
        _confirmPasswordError = '';
      });
    }
  }

  void _validateDate() {
    if (_selectedDate == null) {
      setState(() {
        _dateError = 'Please select a date';
      });
    } else {
      setState(() {
        _dateError = '';
      });
    }
  }

  void _onSignupPressed() async {
  _validateEmail();
  _validateUsername();
  _validatePassword();
  _validateConfirmPassword();
  _validateDate();

  if (_emailError.isEmpty &&
      _usernameError.isEmpty &&
      _passwordError.isEmpty &&
      _confirmPasswordError.isEmpty &&
      _dateError.isEmpty) {
    try {
      _logger.d('Attempting sign up at ${DateTime.now()}: ${emailController.text}, ${usernameController.text}');
      bool success = await _apiService.signUpChild(
        emailController.text,
        usernameController.text,
        passwordController.text,
        _selectedDate!.day,
        _selectedDate!.month,
        _selectedDate!.year,
      );
      _logger.d('Sign up success: $success');
      if (!mounted) return;
      if (success) {
        _logger.d('Signup successful');
        showSuccessPrompt(context); // Show success prompt
      } else {
        _logger.e('Signup failed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signup failed')),
        );
      }
    } catch (e) {
      _logger.e('Signup failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
    }
  }
}


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[200]!, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        dateOfBirthController.text = DateFormat.yMMMMd().format(picked); // Display the selected date with month name
      });
    }
  }

  @override
  void initState() {
    super.initState();

    emailFocusNode.addListener(() {
      if (!emailFocusNode.hasFocus) {
        _validateEmail();
      }
    });

    usernameFocusNode.addListener(() {
      if (!usernameFocusNode.hasFocus) {
        _validateUsername();
      }
    });

    passwordFocusNode.addListener(() {
      if (!passwordFocusNode.hasFocus) {
        _validatePassword();
      }
    });

    confirmPasswordFocusNode.addListener(() {
      if (!confirmPasswordFocusNode.hasFocus) {
        _validateConfirmPassword();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Sign Up', isLoggedIn: false),
      body: SingleChildScrollView(
        padding: appMargin,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                focusNode: emailFocusNode,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  errorText: _emailError.isNotEmpty ? _emailError : null,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: usernameController,
                focusNode: usernameFocusNode,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  errorText: _usernameError.isNotEmpty ? _usernameError : null,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: passwordController,
                focusNode: passwordFocusNode,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  errorText: _passwordError.isNotEmpty ? _passwordError : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: confirmPasswordController,
                focusNode: confirmPasswordFocusNode,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter your password',
                  errorText: _confirmPasswordError.isNotEmpty ? _confirmPasswordError : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureConfirmPassword,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: dateOfBirthController,
                readOnly: true,
                onTap: () => _selectDate(context),
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  hintText: 'Select your birth date',
                  errorText: _dateError.isNotEmpty ? _dateError : null,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _onSignupPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[200],
                ),
                child: const Text('Create'),
              ),
              const SizedBox(height: 20),
              RichText(
                text: TextSpan(
                  text: 'Already using Famie? ',
                  style: const TextStyle(fontSize: 16.0, color: Colors.black, fontFamily: 'Georgia'),
                  children: <TextSpan>[
                    TextSpan(
                      text: 'Log in',
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        fontSize: 16.0,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
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
    emailFocusNode.dispose();
    usernameFocusNode.dispose();
    passwordFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    dateOfBirthController.dispose();
    super.dispose();
  }
}
*/