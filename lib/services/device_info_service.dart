// filename: services/device_info_service.dart(saving device info to database .)1
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class DeviceInfoService {
  final Logger logger = Logger();
  final String baseUrl = Config.baseUrl;
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  Future<String?> _getMacAddress() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Android MAC address is not directly accessible, consider another unique ID like 'androidId'
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor; // iOS doesn't provide MAC address either, but this is a unique ID
      }
    } catch (e) {
      logger.e('Error retrieving MAC address: $e');
    }
    return null;
  }

  Future<String?> _getAndroidId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Return Android ID
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor; // Return iOS unique identifier
      }
    } catch (e) {
      logger.e('Error retrieving Android ID: $e');
    }
    return null;
  }

  Future<void> sendDeviceInfo(BuildContext context, String childId, String deviceName) async {
    final macAddress = await _getMacAddress() ?? 'Unknown';
    final androidId = await _getAndroidId() ?? 'Unknown'; // Fetch Android ID
    final url = Uri.parse('$baseUrl/api/device-info');
    
    try {
      final data = {
        'childId': childId,
        'deviceName': deviceName,
        'macAddress': macAddress,
        'androidId': androidId, // Include Android ID in the data
      };
      logger.i('Sending device info: ${jsonEncode(data)}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        logger.i('Device info sent successfully');
      } else {
        logger.e('Failed to send device info: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      logger.e('Error sending device info: $e');
    }
  }
}


/*
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class DeviceInfoService {
  final Logger logger = Logger();
  final String baseUrl = Config.baseUrl;
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  Future<String?> _getMacAddress() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Android MAC address is not directly accessible, consider another unique ID like 'androidId'
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor; // iOS doesn't provide MAC address either, but this is a unique ID
      }
    } catch (e) {
      logger.e('Error retrieving device info: $e');
    }
    return null;
  }

  Future<void> sendDeviceInfo(BuildContext context, String childId, String deviceName) async {
    final macAddress = await _getMacAddress() ?? 'Unknown';
    final url = Uri.parse('$baseUrl/api/device-info');
    try {
      final data = {
        'childId': childId,
        'deviceName': deviceName,
        'macAddress': macAddress,
      };
      logger.i('Sending device info: ${jsonEncode(data)}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        logger.i('Device info sent successfully');
      } else {
        logger.e('Failed to send device info: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      logger.e('Error sending device info: $e');
    }
  }
}
*/