// filename: lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'config.dart'; 

class ThemeService {
  final String baseUrl = Config.baseUrl; 
  final Logger logger = Logger();

  Future<ThemeData> fetchTheme(String adminId) async {
    try {
      // Make sure you're using the correct endpoint in your backend
      final response = await http.get(Uri.parse('$baseUrl/api/theme?admin_id=$adminId'), headers: {
        'Accept': 'application/json',
      });

      logger.d('Response status: ${response.statusCode}');
      logger.d('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final theme = json.decode(response.body);
        return _createThemeData(theme);
      } else {
        logger.e('Failed to fetch theme: ${response.body}');
        throw Exception('Failed to fetch theme');
      }
    } catch (e) {
      logger.e('Exception during fetch theme: $e');
      throw Exception('Failed to fetch theme: $e');
    }
  }

  Color _parseColor(String color) {
    if (color.startsWith('#')) {
      color = color.substring(1);
    }
    return Color(int.parse('FF$color', radix: 16));
  }

  ThemeData _createThemeData(Map<String, dynamic> theme) {
    return ThemeData(
      primarySwatch: Colors.green,
      fontFamily: theme['font_style'],
      scaffoldBackgroundColor: _parseColor(theme['background_color']),
      appBarTheme: AppBarTheme(
        backgroundColor: _parseColor(theme['app_bar_color']),
      ),
      inputDecorationTheme: InputDecorationTheme(
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _parseColor(theme['app_bar_color'])),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _parseColor(theme['app_bar_color'])),
        ),
        labelStyle: TextStyle(
          color: _parseColor(theme['app_bar_color']),
          fontFamily: theme['font_style'],
        ),
        hintStyle: TextStyle(
          color: _parseColor(theme['app_bar_color']),
          fontFamily: theme['font_style'],
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(_parseColor(theme['button_color'])),
          foregroundColor: WidgetStateProperty.all(Colors.black),
          textStyle: WidgetStateProperty.all(
            TextStyle(fontWeight: FontWeight.bold, fontFamily: theme['font_style']),
          ),
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: const TextStyle(color: Colors.black),
        bodyMedium: const TextStyle(color: Colors.black),
        labelLarge: TextStyle(color: _parseColor(theme['app_bar_color']), fontFamily: theme['font_style']),
        titleLarge: TextStyle(color: _parseColor(theme['app_bar_color']), fontFamily: theme['font_style']),
        titleMedium: TextStyle(color: _parseColor(theme['app_bar_color']), fontFamily: theme['font_style']),
      ),
    );
  }
}

/*
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'config.dart'; 

class ThemeService {
  final String baseUrl = Config.baseUrl; 
  final Logger logger = Logger();

  Future<ThemeData> fetchTheme(String adminId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/theme?admin_id=$adminId'), headers: {
        'Accept': 'application/json',
      });

      logger.d('Response status: ${response.statusCode}');
      logger.d('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final theme = json.decode(response.body);
        return _createThemeData(theme);
      } else {
        logger.e('Failed to fetch theme: ${response.body}');
        throw Exception('Failed to fetch theme');
      }
    } catch (e) {
      logger.e('Exception during fetch theme: $e');
      throw Exception('Failed to fetch theme: $e');
    }
  }

  Color _parseColor(String color) {
    if (color.startsWith('#')) {
      color = color.substring(1);
    }
    return Color(int.parse('FF$color', radix: 16));
  }

  ThemeData _createThemeData(Map<String, dynamic> theme) {
    return ThemeData(
      primarySwatch: Colors.green,
      fontFamily: theme['font_style'],
      scaffoldBackgroundColor: _parseColor(theme['background_color']),
      appBarTheme: AppBarTheme(
        backgroundColor: _parseColor(theme['app_bar_color']),
      ),
      inputDecorationTheme: InputDecorationTheme(
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _parseColor(theme['app_bar_color'])),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _parseColor(theme['app_bar_color'])),
        ),
        labelStyle: TextStyle(
          color: _parseColor(theme['app_bar_color']),
          fontFamily: theme['font_style'],
        ),
        hintStyle: TextStyle(
          color: _parseColor(theme['app_bar_color']),
          fontFamily: theme['font_style'],
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(_parseColor(theme['button_color'])),
          foregroundColor: WidgetStateProperty.all(Colors.black),
          textStyle: WidgetStateProperty.all(
            TextStyle(fontWeight: FontWeight.bold, fontFamily: theme['font_style']),
          ),
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: const TextStyle(color: Colors.black),
        bodyMedium: const TextStyle(color: Colors.black),
        labelLarge: TextStyle(color: _parseColor(theme['app_bar_color']), fontFamily: theme['font_style']),
        titleLarge: TextStyle(color: _parseColor(theme['app_bar_color']), fontFamily: theme['font_style']),
        titleMedium: TextStyle(color: _parseColor(theme['app_bar_color']), fontFamily: theme['font_style']),
      ),
    );
  }
}
*/