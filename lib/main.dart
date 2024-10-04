//filename:main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'services/api_service.dart';
import 'services/theme_service.dart';
import 'design/theme.dart';
import 'home.dart';
import 'child_signup_form.dart';
import 'http_overrides.dart'; // Import the HttpOverrides

Future<void> main() async {
  var logger = Logger();

  try {
    // Print the current working directory
    logger.d('Current working directory: ${Directory.current.path}');
    
    // Print the contents of the directory to verify the .env file is there
    Directory.current.list(recursive: true).listen((entity) {
      logger.d(entity.path);
    });

    // Delay to ensure the directory listing is printed
    await Future.delayed(const Duration(seconds: 2));
  } catch (e) {
    logger.e('Error during startup: $e');
  }

  HttpOverrides.global = MyHttpOverrides(); // Set global HttpOverrides
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<ThemeData> _loadTheme() async {
    final themeService = ThemeService();
    return await themeService.fetchTheme('66965e1ebfcd686202c11838'); 
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ThemeData>(
      future: _loadTheme(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Error loading theme: ${snapshot.error}'),
              ),
            ),
          );
        } else {
          return MaterialApp(
            theme: snapshot.data,
            home: const LoginScreen(),
          );
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Add a form key
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  var logger = Logger();
  ApiService apiService = ApiService();
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();

    _usernameFocusNode.addListener(() {
      if (!_usernameFocusNode.hasFocus) {
        setState(() {}); // Update the state when username field loses focus
      }
    });

    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus) {
        setState(() {}); // Update the state when password field loses focus
      }
    });
  }

  @override
  void dispose() {
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      final username = usernameController.text;
      final password = passwordController.text;

      logger.d('Attempting login with username: $username');

      try {
        var result = await apiService.loginChild(username, password);
        logger.d('Login response: $result');
        if (result['success']) {
          logger.d('Login successful');
          _navigateToHome(result['childId']);
        } else {
          logger.d('Login failed');
          _showDialog('Invalid username or password');
        }
      } catch (e) {
        logger.e('Exception during login: $e');
        _showDialog('An error occurred. Please try again.');
      }
    }
  }

  void _navigateToHome(String childId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(childId: childId)),
    );
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login Failed'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get the theme data
    final appBarColor = theme.appBarTheme.backgroundColor; // Get the AppBar color
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black; // Get the text color from the theme

    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: customAppBar(context, 'Login Screen'),
      body: SingleChildScrollView(
        child: Container(
          margin: mediaQuery.size.width > 600
              ? EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.2)
              : const EdgeInsets.all(20),
          child: Form(
            key: _formKey, // Add the form key to the form widget
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The "Welcome Child" text follows the AppBar color
                Text(
                      'Welcome Child!',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia', // Use theme's font family
                        color: theme.textTheme.bodyLarge?.color ?? Colors.black, // Use theme's text color
                      ),
                    ),

                TextFormField(
                  controller: usernameController,
                  focusNode: _usernameFocusNode, // Attach the focus node
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter your username',
                  ),
                  style: TextStyle(color: textColor), // Set input text color to theme color
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: passwordController,
                  focusNode: _passwordFocusNode, // Attach the focus node
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                        color: appBarColor, // Use AppBar color for the eye icon
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureText,
                  style: TextStyle(color: textColor), // Set input text color to theme color
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.elevatedButtonTheme.style?.backgroundColor?.resolve({}),
                  ), // Use the button color from the theme
                  child: const Text('Log In'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don’t have an account?  ",
                      style: TextStyle(
                        fontSize: 16.0,
                        color: textColor, // Follow theme font color
                        fontFamily: theme.textTheme.bodyLarge?.fontFamily, // Follow theme font style
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChildSignupForm()),
                        );
                      },
                      child: Text(
                        "Create one",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                          color: appBarColor, // Use AppBar color for "Create one"
                          decoration: TextDecoration.underline,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/*
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'services/api_service.dart';
import 'services/theme_service.dart';
import 'design/theme.dart';
import 'home.dart';
import 'child_signup_form.dart';
import 'http_overrides.dart'; // Import the HttpOverrides

Future<void> main() async {
  var logger = Logger();

  try {
    // Print the current working directory
    logger.d('Current working directory: ${Directory.current.path}');
    
    // Print the contents of the directory to verify the .env file is there
    Directory.current.list(recursive: true).listen((entity) {
      logger.d(entity.path);
    });

    // Delay to ensure the directory listing is printed
    await Future.delayed(const Duration(seconds: 2));
  } catch (e) {
    logger.e('Error during startup: $e');
  }

  HttpOverrides.global = MyHttpOverrides(); // Set global HttpOverrides
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<ThemeData> _loadTheme() async {
    final themeService = ThemeService();
    return await themeService.fetchTheme('66965e1ebfcd686202c11838'); 
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ThemeData>(
      future: _loadTheme(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Error loading theme: ${snapshot.error}'),
              ),
            ),
          );
        } else {
          return MaterialApp(
            theme: snapshot.data,
            home: const LoginScreen(),
          );
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Add a form key
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  var logger = Logger();
  ApiService apiService = ApiService();
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();

    _usernameFocusNode.addListener(() {
      if (!_usernameFocusNode.hasFocus) {
        setState(() {}); // Update the state when username field loses focus
      }
    });

    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus) {
        setState(() {}); // Update the state when password field loses focus
      }
    });
  }

  @override
  void dispose() {
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      final username = usernameController.text;
      final password = passwordController.text;

      logger.d('Attempting login with username: $username');

      try {
        var result = await apiService.loginChild(username, password);
        logger.d('Login response: $result');
        if (result['success']) {
          logger.d('Login successful');
          _navigateToHome(result['childId']);
        } else {
          logger.d('Login failed');
          _showDialog('Invalid username or password');
        }
      } catch (e) {
        logger.e('Exception during login: $e');
        _showDialog('An error occurred. Please try again.');
      }
    }
  }

  void _navigateToHome(String childId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(childId: childId)),
    );
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login Failed'),
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: customAppBar(context, 'Login Screen'),
      body: SingleChildScrollView(
        child: Container(
          margin: mediaQuery.size.width > 600
              ? EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.2)
              : const EdgeInsets.all(20),
          child: Form(
            key: _formKey, // Add the form key to the form widget
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome Child!',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                    color: Colors.green[700],
                  ),
                ),
                TextFormField(
                  controller: usernameController,
                  focusNode: _usernameFocusNode, // Attach the focus node
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter your username',
                  ),
                  style: const TextStyle(color: Colors.black), // Set input text color to black
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: passwordController,
                  focusNode: _passwordFocusNode, // Attach the focus node
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureText,
                  style: const TextStyle(color: Colors.black), // Set input text color to black
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}),
                  ), // Use the button color from the theme
                  child: const Text('Log In'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don’t have an account?  ",
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Colors.black,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChildSignupForm()),
                        );
                      },
                      child: Text(
                        "Create one",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                          color: Colors.green[700],
                          decoration: TextDecoration.underline,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
*/
/*
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'services/api_service.dart';
import 'services/theme_service.dart';
import 'design/theme.dart';
import 'home.dart';
import 'child_signup_form.dart';
import 'http_overrides.dart'; // Import the HttpOverrides

Future<void> main() async {
  var logger = Logger();

  try {
    // Print the current working directory
    logger.d('Current working directory: ${Directory.current.path}');
    
    // Print the contents of the directory to verify the .env file is there
    Directory.current.list(recursive: true).listen((entity) {
      logger.d(entity.path);
    });

    // Delay to ensure the directory listing is printed
    await Future.delayed(const Duration(seconds: 2));
  } catch (e) {
    logger.e('Error during startup: $e');
  }

  HttpOverrides.global = MyHttpOverrides(); // Set global HttpOverrides
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<ThemeData> _loadTheme() async {
    final themeService = ThemeService();
    return await themeService.fetchTheme('66965e1ebfcd686202c11838'); 
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ThemeData>(
      future: _loadTheme(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Error loading theme: ${snapshot.error}'),
              ),
            ),
          );
        } else {
          return MaterialApp(
            theme: snapshot.data,
            home: const LoginScreen(),
          );
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Add a form key
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  var logger = Logger();
  ApiService apiService = ApiService();
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();

    _usernameFocusNode.addListener(() {
      if (!_usernameFocusNode.hasFocus) {
        setState(() {}); // Update the state when username field loses focus
      }
    });

    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus) {
        setState(() {}); // Update the state when password field loses focus
      }
    });
  }

  @override
  void dispose() {
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      final username = usernameController.text;
      final password = passwordController.text;

      logger.d('Attempting login with username: $username');

      try {
        var result = await apiService.loginChild(username, password);
        logger.d('Login response: $result');
        if (result['success']) {
          logger.d('Login successful');
          _navigateToHome(result['childId']);
        } else {
          logger.d('Login failed');
          _showDialog('Invalid username or password');
        }
      } catch (e) {
        logger.e('Exception during login: $e');
        _showDialog('An error occurred. Please try again.');
      }
    }
  }

  void _navigateToHome(String childId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(childId: childId)),
    );
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login Failed'),
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: customAppBar(context, 'Login Screen'),
      body: SingleChildScrollView(
        child: Container(
          margin: mediaQuery.size.width > 600
              ? EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.2)
              : const EdgeInsets.all(20),
          child: Form(
            key: _formKey, // Add the form key to the form widget
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome Child!',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                    color: Colors.green[700],
                  ),
                ),
                TextFormField(
                  controller: usernameController,
                  focusNode: _usernameFocusNode, // Attach the focus node
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter your username',
                  ),
                  style: const TextStyle(color: Colors.black), // Set input text color to black
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: passwordController,
                  focusNode: _passwordFocusNode, // Attach the focus node
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureText,
                  style: const TextStyle(color: Colors.black), // Set input text color to black
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[200],
                  ),
                  child: const Text('Log In'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don’t have an account?  ",
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Colors.black,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChildSignupForm()),
                        );
                      },
                      child: Text(
                        "Create one",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                          color: Colors.green[700],
                          decoration: TextDecoration.underline,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
*/