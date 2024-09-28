//filename:functions/device_info.dart
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

Future<Map<String, String>> getDeviceInfo() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

  // Get the device name
  String deviceName = androidInfo.model ?? 'Unknown';

  // Initialize the logger
  var logger = Logger();

  // Get the Android ID as fallback for MAC address
  String androidId = androidInfo.id ?? 'Unknown Android ID';

  // Get the MAC address
  String macAddress = 'Unknown';  // Default to 'Unknown'
  final connectivityResult = await Connectivity().checkConnectivity();

  // Only check MAC address if connected to Wi-Fi (although restricted on Android 10+)
  if (connectivityResult == ConnectivityResult.wifi) {
    macAddress = 'Wi-Fi connected, but MAC unavailable on Android 10+';
  } else {
    macAddress = 'No Wi-Fi connection';
  }

  // Log the information
  logger.i('Device Info: $deviceName, $macAddress (Fallback: Android ID: $androidId)');

  // Return both MAC address and Android ID
  return {
    'deviceName': deviceName,
    'macAddress': macAddress,
    'androidId': androidId,  // Added Android ID as fallback
  };
}



/*
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wifi_info_flutter/wifi_info_flutter.dart';
import 'package:logger/logger.dart';

Future<Map<String, String>> getDeviceInfo() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

  // Get the device name
  String deviceName = androidInfo.model ?? 'Unknown';

  // Initialize the logger
  var logger = Logger();

  // Get the MAC address
  String macAddress = 'Unknown';
  final connectivityResult = await Connectivity().checkConnectivity();

  if (connectivityResult == ConnectivityResult.wifi) {
    try {
      final wifiBSSID = await WifiInfo().getWifiBSSID();
      if (wifiBSSID != null) {
        macAddress = wifiBSSID;
      }
    } catch (e) {
      logger.e("Error retrieving MAC address: $e");
    }
  }

  logger.i('Device Info: $deviceName, $macAddress'); // Log the device info

  return {
    'deviceName': deviceName,
    'macAddress': macAddress,
  };
}
*/
/*
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wifi_info_flutter/wifi_info_flutter.dart';
import 'package:logger/logger.dart';

Future<Map<String, String>> getDeviceInfo() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

  // Get the device name
  String deviceName = androidInfo.model ?? 'Unknown';

  // Initialize the logger
  var logger = Logger();

  // Get the MAC address
  String macAddress = 'Unknown';
  final connectivityResult = await Connectivity().checkConnectivity();

  if (connectivityResult == ConnectivityResult.wifi) {
    try {
      final wifiBSSID = await WifiInfo().getWifiBSSID();
      if (wifiBSSID != null) {
        macAddress = wifiBSSID;
      }
    } catch (e) {
      logger.e("Error retrieving MAC address: $e");
    }
  }

  logger.i('Device Info: $deviceName, $macAddress'); // Log the device info

  return {
    'deviceName': deviceName,
    'macAddress': macAddress,
  };
}
*/