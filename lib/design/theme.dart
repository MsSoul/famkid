// filename: design/theme.dart

import 'package:flutter/material.dart';
import '../services/theme_service.dart'; // Import the theme service
import 'package:logger/logger.dart';

// Create a StatefulWidget to handle theme fetching and dynamic application
class AppThemeManager extends StatefulWidget {
  final Widget child; // This allows you to wrap your app with the theme

  const AppThemeManager({super.key, required this.child});

  @override
  AppThemeManagerState createState() => AppThemeManagerState();
}

class AppThemeManagerState extends State<AppThemeManager> {
  ThemeData _appTheme = ThemeData.light(); // Default theme
  final ThemeService _themeService = ThemeService(); // Instantiate theme service
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchAndApplyTheme(); // Fetch and apply the theme on initialization
  }

  Future<void> _fetchAndApplyTheme() async {
    try {
      String adminId = "66965e1ebfcd686202c11838"; // Replace with your actual adminId or retrieve it dynamically
      ThemeData fetchedTheme = await _themeService.fetchTheme(adminId);
      setState(() {
        _appTheme = fetchedTheme;
      });
    } catch (e) {
      _logger.e("Error fetching theme: $e");
      // Fallback to a default theme if fetching fails
      setState(() {
        _appTheme = ThemeData.light();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: _appTheme, // Apply the dynamically fetched theme
      home: widget.child, // Use the child widget passed in
    );
  }
}

// Customize the font style and color based on the theme service data
ThemeData createCustomTheme(Map<String, dynamic> themeData) {
  return ThemeData(
    primarySwatch: Colors.green, // You can modify this based on your data
    fontFamily: themeData['font_style'] ?? 'Georgia', // Dynamic font family
    scaffoldBackgroundColor: Color(int.parse('0xFF${themeData['background_color'].substring(1)}')), // Dynamic background color
    appBarTheme: AppBarTheme(
      backgroundColor: Color(int.parse('0xFF${themeData['app_bar_color'].substring(1)}')), // Dynamic app bar color
    ),
    inputDecorationTheme: InputDecorationTheme(
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color.fromARGB(255, 9, 10, 9)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color.fromARGB(255, 9, 10, 9)),
      ),
      labelStyle: TextStyle(
        color: Color(int.parse('0xFF${themeData['text_color'].substring(1)}')), // Dynamic label color
        fontFamily: themeData['font_style'] ?? 'Georgia', // Dynamic font family
      ),
      hintStyle: TextStyle(
        color: Colors.grey,
        fontFamily: themeData['font_style'] ?? 'Georgia', // Dynamic hint style
      ),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Color(int.parse('0xFF${themeData['text_color'].substring(1)}'))), // Dynamic text color
      bodyMedium: TextStyle(color: Color(int.parse('0xFF${themeData['text_color'].substring(1)}'))), // Dynamic text color
      titleLarge: TextStyle(
        color: const Color.fromARGB(255, 167, 169, 167),
        fontFamily: themeData['font_style'] ?? 'Georgia', // Dynamic font family
      ),
      titleMedium: TextStyle(
        color: const Color.fromARGB(255, 167, 169, 167),
        fontFamily: themeData['font_style'] ?? 'Georgia', // Dynamic font family
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Color(int.parse('0xFF${themeData['button_color'].substring(1)}'))), // Dynamic button color
        foregroundColor: WidgetStateProperty.all(Colors.black),
        textStyle: WidgetStateProperty.all(
          TextStyle(fontWeight: FontWeight.bold, fontFamily: themeData['font_style'] ?? 'Georgia'), // Dynamic font family
        ),
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
        ),
      ),
    ),
  );
}

// Custom AppBar
AppBar customAppBar(BuildContext context, String title, {bool isLoggedIn = false}) {
  return AppBar(
    title: Image.asset(
      'assets/image1.png',
      height: 150.0,
      width: 170.0,
    ),
    centerTitle: true,
  );
}

const EdgeInsets appMargin = EdgeInsets.all(40.0);

// Example usage of the AppThemeManager to wrap the app:
void main() {
  runApp(const AppThemeManager(
    child: MyHomePage(),
  ));
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Home'),
      body: const Center(
        child: Text('Welcome to the dynamically themed app!'),
      ),
    );
  }
}

/*
import 'package:flutter/material.dart';


final ThemeData appTheme = ThemeData(
  primarySwatch: Colors.green,
  fontFamily: 'Georgia',
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.green[200],
  ),
  inputDecorationTheme: const InputDecorationTheme(
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Color.fromARGB(255, 9, 10, 9)),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Color.fromARGB(255, 9, 10, 9)),
    ),
    labelStyle: TextStyle(
      color: Color.fromARGB(255, 9, 10, 9),
      fontFamily: 'Georgia',
    ),
    hintStyle: TextStyle(
      color: Colors.grey,
      fontFamily: 'Georgia',
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black),
    bodyMedium: TextStyle(color: Colors.black),
    titleLarge: TextStyle(color: Color.fromARGB(255, 167, 169, 167), fontFamily: 'Georgia'),
    titleMedium: TextStyle(color: Color.fromARGB(255, 167, 169, 167), fontFamily: 'Georgia'),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all(Colors.green[200]),
      foregroundColor: WidgetStateProperty.all(Colors.black),
      textStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Georgia'),
      ),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
    ),
  ),
);

const EdgeInsets appMargin = EdgeInsets.all(40.0);

AppBar customAppBar(BuildContext context, String title, {bool isLoggedIn = false}) {
  return AppBar(
    title: Image.asset(
      'assets/image1.png',
      height: 150.0,
      width: 170.0,
    ),
    centerTitle: true,
  );
}
*/