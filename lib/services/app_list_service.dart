// filename: services/app_list_service.dart (pagkuha ni ug list of apps)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'config.dart'; 

class AppListService {
  final Logger logger = Logger();
  final String baseUrl = Config.baseUrl; 

  static const platform = MethodChannel('com.example.app/app_list');

  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getInstalledApps');
      logger.i('Installed apps: $result');
      return result.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      logger.e('Failed to get installed apps: $e');
      return [];
    }
  }

  Future<void> sendAppList(BuildContext context, String childId, List<Map<String, dynamic>> systemApps, List<Map<String, dynamic>> userApps) async {
  final url = Uri.parse('$baseUrl/api/app-list');
  try {
    final data = {
      'childId': childId,
      'systemApps': systemApps,
      'userApps': userApps,
    };
    logger.i('Sending app list: ${jsonEncode(data)}');
    
    // Log each app
    for (var app in systemApps) {
      logger.i('SystemAppName: ${app['appName']}, PackageName: ${app['packageName']}');
    }
    for (var app in userApps) {
      logger.i('UserAppName: ${app['appName']}, PackageName: ${app['packageName']}');
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      logger.i('App list sent successfully');
    } else {
      logger.e('Failed to send app list: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    logger.e('Error sending app list: $e');
  }
}


}