// filename: design/theme.dart
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
