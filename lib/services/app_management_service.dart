// filename: ../services/app_management_service.dart (blocking apps ni)
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger();

class AppManagementService {
  static const platform = MethodChannel('com.example.app/block');

  // Fetch the apps from the app_management collection
Future<Map<String, List<String>>> fetchApps(String childId) async {
  final url = Uri.parse('${Config.baseUrl}/api/fetch-apps?childId=$childId');

  logger.i('Requesting apps from: $url');

  try {
    final response = await http.get(url);
    logger.i('HTTP Status Code: ${response.statusCode}');
    logger.i('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      logger.i('Decoded Data: $data');

      if (data == null) {
        logger.e('Error: Decoded response is null');
        return {};
      }

      // Fetch all apps and segregate blocked and allowed apps based on `is_allowed` field
      List<String> blockedApps = (data['apps'] as List?)
          ?.where((app) => app['is_allowed'] == false)
          .map((app) => app['package_name'].toString())
          .toList() ?? [];
      List<String> allowedApps = (data['apps'] as List?)
          ?.where((app) => app['is_allowed'] == true)
          .map((app) => app['package_name'].toString())
          .toList() ?? [];

      logger.i('Blocked Apps: $blockedApps');
      logger.i('Allowed Apps: $allowedApps');

      return {'blocked': blockedApps, 'allowed': allowedApps};
    } else {
      logger.e('Failed to fetch apps: ${response.statusCode} - ${response.reasonPhrase}');
      return {};
    }
  } catch (error) {
    logger.e('Error fetching apps: $error');
    return {};
  }
}


  // Block/unblock an app on the device using MethodChannel
 // Block/unblock an app on the device using MethodChannel
Future<void> updateAppOnDevice(Map<String, dynamic> app) async {
  logger.i("App data received: $app");

  // Retrieve the package name and is_allowed from the app map
  String? packageName = app['package_name'];
  bool? isAllowed = app['is_allowed'];

  // Log the package name and isAllowed to verify if they are correctly retrieved
  logger.i("Package name: $packageName, isAllowed: $isAllowed");

  // Check if either package name or isAllowed is null
  if (packageName == null || isAllowed == null) {
    logger.e("Error: Package name or isAllowed status is null for app: $app");
    throw PlatformException(
      code: 'INVALID_PACKAGE',
      message: 'Package name or isAllowed status is null',
    );
  }

  try {
  logger.i("Invoking native method with package_name: $packageName and is_allowed: $isAllowed");

final result = await platform.invokeMethod('blockApp', {
  'package_name': packageName,
  'is_allowed': isAllowed,
});

  logger.i("App processed successfully: $packageName, allowed: $isAllowed, result: $result");
} catch (e) {
  logger.e("Failed to process app: $packageName, Error: $e");
  rethrow;
}
}

  // Apply blocking/unblocking apps fetched from backend
 // Apply blocking/unblocking apps fetched from backend
Future<void> applyAppSettings(Map<String, List<String>> apps) async {
  List<String> blockedApps = apps['blocked'] ?? [];
  List<String> allowedApps = apps['allowed'] ?? [];

  if (blockedApps.isEmpty && allowedApps.isEmpty) {
    logger.i('No apps to block or unblock.');
    return;
  }

  // Block apps
  for (String packageName in blockedApps) {
    logger.i("Attempting to block app: $packageName");
    try {
      await updateAppOnDevice({'package_name': packageName, 'is_allowed': false});
    } catch (e) {
      logger.e('Failed to block app: $packageName, Error: $e');
    }
  }

  // Unblock apps
  for (String packageName in allowedApps) {
    logger.i("Attempting to unblock app: $packageName");
    try {
      await updateAppOnDevice({'package_name': packageName, 'is_allowed': true});
    } catch (e) {
      logger.e('Failed to unblock app: $packageName, Error: $e');
    }
  }

  logger.i('All apps processed for blocking and unblocking.');
}


  // Fetch and apply app settings on the device
  Future<void> fetchAndApplyAppSettings(String childId) async {
    logger.i('Fetching apps for childId: $childId');

    // Fetch apps from the backend
    Map<String, List<String>> apps = await fetchApps(childId);

    if (apps.isEmpty) {
      logger.i('No apps to block or unblock.');
      return;
    }

    // Apply blocking and unblocking of apps
    await applyAppSettings(apps);

    logger.i('App settings applied successfully.');
  }

  // Save blocked/allowed apps to the backend
  Future<void> saveBlockedApps(String childId, List<String> blockedApps, List<String> allowedApps) async {
    final url = Uri.parse('${Config.baseUrl}/api/save-blocked-apps');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'childId': childId,
          'blocked_apps': blockedApps,
          'allowed_apps': allowedApps,
        }),
      );

      logger.i('HTTP Status Code: ${response.statusCode}');
      logger.i('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        logger.i('Blocked apps saved successfully');
      } else {
        logger.e('Failed to save blocked apps: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (error) {
      logger.e('Error saving blocked apps: $error');
    }
  }
}

/* mugana ni makakuha na ug list sa apps na block and not ang problema (INVALID_PACKAGE, Package name or isAllowed status is null, null, null)
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger();

class AppManagementService {
  static const platform = MethodChannel('com.example.app/block');

  // Fetch the apps from the app_management collection
  Future<Map<String, List<String>>> fetchApps(String childId) async {
    final url = Uri.parse('${Config.baseUrl}/api/fetch-apps?childId=$childId');

    logger.i('Requesting apps from: $url');

    try {
      final response = await http.get(url);
      logger.i('HTTP Status Code: ${response.statusCode}');
      logger.i('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Decoded Data: $data');

        if (data == null) {
          logger.e('Error: Decoded response is null');
          return {};
        }

        // Fetch all apps and segregate blocked and allowed apps based on `is_allowed` field
        List<String> blockedApps = (data['apps'] as List?)
            ?.where((app) => app['is_allowed'] == false)
            .map((app) => app['package_name'].toString())
            .toList() ?? [];
        List<String> allowedApps = (data['apps'] as List?)
            ?.where((app) => app['is_allowed'] == true)
            .map((app) => app['package_name'].toString())
            .toList() ?? [];

        logger.i('Blocked Apps: $blockedApps');
        logger.i('Allowed Apps: $allowedApps');

        return {'blocked': blockedApps, 'allowed': allowedApps};
      } else {
        logger.e('Failed to fetch apps: ${response.statusCode} - ${response.reasonPhrase}');
        return {};
      }
    } catch (error) {
      logger.e('Error fetching apps: $error');
      return {};
    }
  }

  // Block/unblock an app on the device using MethodChannel
 Future<void> updateAppOnDevice(Map<String, dynamic> app) async {
  logger.i("App data received: $app");

  // Retrieve the package name and is_allowed from the app map
  String? packageName = app['package_name'];
  bool? isAllowed = app['is_allowed'];

  // Log the package name and isAllowed to verify if they are correctly retrieved
  logger.i("Package name: $packageName, isAllowed: $isAllowed");

  // Check if either package name or isAllowed is null
  if (packageName == null || isAllowed == null) {
    logger.e("Error: Package name or isAllowed status is null for app: $app");
    throw PlatformException(
      code: 'INVALID_PACKAGE',
      message: 'Package name or isAllowed status is null',
    );
  }

  try {
    // Call the native method to block/unblock the app
    await platform.invokeMethod('blockApp', {
      'package_name': packageName,
      'is_allowed': isAllowed,
    });

    logger.i("App processed successfully: $packageName, allowed: $isAllowed");
  } catch (e) {
    logger.e("Failed to process app: $packageName, Error: $e");
    rethrow; // Re-throw the caught exception
  }
}


  // Apply blocking/unblocking apps fetched from backend
  Future<void> applyAppSettings(Map<String, List<String>> apps) async {
    List<String> blockedApps = apps['blocked'] ?? [];
    List<String> allowedApps = apps['allowed'] ?? [];

    if (blockedApps.isEmpty && allowedApps.isEmpty) {
      logger.i('No apps to block or unblock.');
      return;
    }

    // Block apps
    for (String packageName in blockedApps) {
      await updateAppOnDevice({'package_name': packageName, 'is_allowed': false}); // Fixed the argument
    }

    // Unblock apps
    for (String packageName in allowedApps) {
      await updateAppOnDevice({'package_name': packageName, 'is_allowed': true}); // Fixed the argument
    }

    logger.i('All apps processed for blocking and unblocking.');
  }

  // Fetch and apply app settings on the device
  Future<void> fetchAndApplyAppSettings(String childId) async {
    logger.i('Fetching apps for childId: $childId');

    // Fetch apps from the backend
    Map<String, List<String>> apps = await fetchApps(childId);

    if (apps.isEmpty) {
      logger.i('No apps to block or unblock.');
      return;
    }

    // Apply blocking and unblocking of apps
    await applyAppSettings(apps);

    logger.i('App settings applied successfully.');
  }

  // Save blocked/allowed apps to the backend
  Future<void> saveBlockedApps(String childId, List<String> blockedApps, List<String> allowedApps) async {
    final url = Uri.parse('${Config.baseUrl}/api/save-blocked-apps');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'childId': childId,
          'blocked_apps': blockedApps,
          'allowed_apps': allowedApps,
        }),
      );

      logger.i('HTTP Status Code: ${response.statusCode}');
      logger.i('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        logger.i('Blocked apps saved successfully');
      } else {
        logger.e('Failed to save blocked apps: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (error) {
      logger.e('Error saving blocked apps: $error');
    }
  }
}

*/
/*ma separate na niya ang block apps and allowed appf from app management
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger();

class AppManagementService {
  static const platform = MethodChannel('com.example.app/block');

  // Fetch the apps from the app_management collection
  Future<Map<String, List<String>>> fetchApps(String childId) async {
    final url = Uri.parse('${Config.baseUrl}/api/fetch-apps?childId=$childId');

    logger.i('Requesting apps from: $url');

    try {
      final response = await http.get(url);
      logger.i('HTTP Status Code: ${response.statusCode}');
      logger.i('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Decoded Data: $data');

        if (data == null) {
          logger.e('Error: Decoded response is null');
          return {};
        }

        // Fetch all apps and segregate blocked and allowed apps based on `is_allowed` field
        List<String> blockedApps = (data['apps'] as List?)
            ?.where((app) => app['is_allowed'] == false)
            .map((app) => app['package_name'].toString())
            .toList() ?? [];
        List<String> allowedApps = (data['apps'] as List?)
            ?.where((app) => app['is_allowed'] == true)
            .map((app) => app['package_name'].toString())
            .toList() ?? [];

        logger.i('Blocked Apps: $blockedApps');
        logger.i('Allowed Apps: $allowedApps');

        return {'blocked': blockedApps, 'allowed': allowedApps};
      } else {
        logger.e('Failed to fetch apps: ${response.statusCode} - ${response.reasonPhrase}');
        return {};
      }
    } catch (error) {
      logger.e('Error fetching apps: $error');
      return {};
    }
  }

  // Block/unblock an app on the device using MethodChannel
  Future<void> updateAppOnDevice(String packageName, bool isBlocked) async {
    try {
      await platform.invokeMethod('blockApp', {
        "packageName": packageName,
        "isBlocked": isBlocked,
      });
      logger.i("${isBlocked ? 'Blocked' : 'Unblocked'} app: $packageName");
    } catch (e) {
      logger.e("Failed to ${isBlocked ? 'block' : 'unblock'} app: $packageName, Error: $e");
    }
  }

  // Apply blocking/unblocking apps fetched from backend
  Future<void> applyAppSettings(Map<String, List<String>> apps) async {
    List<String> blockedApps = apps['blocked'] ?? [];
    List<String> allowedApps = apps['allowed'] ?? [];

    if (blockedApps.isEmpty && allowedApps.isEmpty) {
      logger.i('No apps to block or unblock.');
      return;
    }

    // Block apps
    for (String packageName in blockedApps) {
      await updateAppOnDevice(packageName, true);
    }

    // Unblock apps
    for (String packageName in allowedApps) {
      await updateAppOnDevice(packageName, false);
    }

    logger.i('All apps processed for blocking and unblocking.');
  }

  // Fetch and apply app settings on the device
  Future<void> fetchAndApplyAppSettings(String childId) async {
    logger.i('Fetching apps for childId: $childId');

    // Fetch apps from the backend
    Map<String, List<String>> apps = await fetchApps(childId);

    if (apps.isEmpty) {
      logger.i('No apps to block or unblock.');
      return;
    }

    // Apply blocking and unblocking of apps
    await applyAppSettings(apps);

    logger.i('App settings applied successfully.');
  }

  // Save blocked/allowed apps to the backend
  Future<void> saveBlockedApps(String childId, List<String> blockedApps, List<String> allowedApps) async {
    final url = Uri.parse('${Config.baseUrl}/api/save-blocked-apps');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'childId': childId,
          'blocked_apps': blockedApps,
          'allowed_apps': allowedApps,
        }),
      );

      logger.i('HTTP Status Code: ${response.statusCode}');
      logger.i('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        logger.i('Blocked apps saved successfully');
      } else {
        logger.e('Failed to save blocked apps: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (error) {
      logger.e('Error saving blocked apps: $error');
    }
  }
}
*/

/*from app_mangement to block apps ni. 
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger();

class AppManagementService {
  static const platform = MethodChannel('com.example.app/block');

  // Fetch the apps from the block_apps collection
  Future<Map<String, List<String>>> fetchApps(String childId) async {
    final url = Uri.parse('${Config.baseUrl}/blocked-apps?childId=$childId');
    logger.i('Requesting apps from: $url');

    try {
      final response = await http.get(url);
      logger.i('HTTP Status Code: ${response.statusCode}');
      logger.i('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Decoded Data: $data');

        if (data == null) {
          logger.e('Error: Decoded response is null');
          return {};
        }

        // Fetch blocked and allowed apps
        List<String> blockedApps = (data['blocked_apps'] as List?)
            ?.map((app) => app['package_name'].toString())
            .toList() ?? [];
        List<String> allowedApps = (data['allowed_apps'] as List?)
            ?.map((app) => app['package_name'].toString())
            .toList() ?? [];

        logger.i('Blocked Apps: $blockedApps');
        logger.i('Allowed Apps: $allowedApps');

        return {'blocked': blockedApps, 'allowed': allowedApps};
      } else {
        logger.e('Failed to fetch apps: ${response.statusCode} - ${response.reasonPhrase}');
        return {};
      }
    } catch (error) {
      logger.e('Error fetching apps: $error');
      return {};
    }
  }

  // Block/unblock an app on the device using MethodChannel
  Future<void> updateAppOnDevice(String packageName, bool isBlocked) async {
    try {
      await platform.invokeMethod('blockApp', {
        "packageName": packageName,
        "isBlocked": isBlocked,
      });
      logger.i("${isBlocked ? 'Blocked' : 'Unblocked'} app: $packageName");
    } catch (e) {
      logger.e("Failed to ${isBlocked ? 'block' : 'unblock'} app: $packageName, Error: $e");
    }
  }

  // Apply blocking/unblocking apps fetched from backend
  Future<void> applyAppSettings(Map<String, List<String>> apps) async {
    List<String> blockedApps = apps['blocked'] ?? [];
    List<String> allowedApps = apps['allowed'] ?? [];

    if (blockedApps.isEmpty && allowedApps.isEmpty) {
      logger.i('No apps to block or unblock.');
      return;
    }

    // Block apps
    for (String packageName in blockedApps) {
      await updateAppOnDevice(packageName, true);
    }

    // Unblock apps
    for (String packageName in allowedApps) {
      await updateAppOnDevice(packageName, false);
    }

    logger.i('All apps processed for blocking and unblocking.');
  }

  // Fetch and apply app settings on the device
  Future<void> fetchAndApplyAppSettings(String childId) async {
    logger.i('Fetching apps for childId: $childId');

    // Fetch apps from the backend
    Map<String, List<String>> apps = await fetchApps(childId);

    if (apps.isEmpty) {
      logger.i('No apps to block or unblock.');
      return;
    }

    // Apply blocking and unblocking of apps
    await applyAppSettings(apps);

    logger.i('App settings applied successfully.');
  }

  // Save blocked/allowed apps to the backend
  Future<void> saveBlockedApps(String childId, List<String> blockedApps, List<String> allowedApps) async {
    final url = Uri.parse('${Config.baseUrl}/api/save-blocked-apps'); // Ensure the '/api' prefix is correct if necessary

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'childId': childId,
          'blocked_apps': blockedApps,
          'allowed_apps': allowedApps,
        }),
      );

      // Log the response status and body for debugging
      logger.i('HTTP Status Code: ${response.statusCode}');
      logger.i('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        logger.i('Blocked apps saved successfully');
      } else {
        logger.e('Failed to save blocked apps: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (error) {
      logger.e('Error saving blocked apps: $error');
    }
  }
}
*/

/*mugana man kaso no apps to block ang error
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger();

class AppManagementService {
  // MethodChannel for blocking apps on the device
  static const platform = MethodChannel('com.example.app/block');

  // Function to fetch blocked apps from the backend
  Future<List<String>> fetchBlockedApps(String childId) async {
    final url = Uri.parse('${Config.baseUrl}/blocked-apps?childId=$childId');

    try {
      final response = await http.get(url);
      logger.i('Raw Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Decoded data: $data');

        if (data == null || data['success'] != true) {
          logger.e('Failed to fetch blocked apps: ${data['message']}');
          return [];
        }

        // Check if apps are null or empty
        if (data['apps'] == null || (data['apps'] as List).isEmpty) {
          logger.i('No apps to block. Message from backend: ${data['message']}');
          return [];
        }

        // Log and return the blocked apps list
        List<String> blockedApps = (data['apps'] as List)
            .map((app) => app['package_name'].toString())
            .toList();
        logger.i('Blocked apps retrieved: $blockedApps');
        return blockedApps;
      } else {
        logger.e('Failed to fetch blocked apps: ${response.statusCode} - ${response.reasonPhrase}');
        return [];
      }
    } catch (error) {
      logger.e('Error fetching blocked apps: $error');
      return [];
    }
  }

  // Function to block a single app on the device using MethodChannel
  Future<void> blockAppOnDevice(String packageName) async {
    try {
      await platform.invokeMethod('blockApp', {"packageName": packageName});
      logger.i("Successfully blocked app: $packageName");
    } catch (e) {
      logger.e("Failed to block app: $packageName, Error: $e");
    }
  }

  // Function to block all apps fetched from the backend
  Future<void> blockApps(List<String> blockedApps) async {
    if (blockedApps.isEmpty) {
      logger.i('No apps to block.');
      return;
    }

    for (String packageName in blockedApps) {
      await blockAppOnDevice(packageName);
    }
    logger.i('All blocked apps processed.');
  }

  // Main function to fetch blocked apps and block them on the device
  Future<void> fetchAndBlockApps(String childId) async {
    logger.i('Fetching blocked apps for childId: $childId');

    // Fetch blocked apps from the backend
    List<String> blockedApps = await fetchBlockedApps(childId);

    // Check if there are no apps to block
    if (blockedApps.isEmpty) {
      logger.i('No apps to block.');
      return;
    }

    // Block the retrieved apps on the device
    await blockApps(blockedApps);

    logger.i('Apps successfully blocked.');
  }
}

*/

/*
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger();

class AppManagementService {
  static const platform = MethodChannel('com.example.app/block');

  // Function to fetch blocked apps from the backend
  // Function to fetch blocked apps from the backend
Future<List<String>> fetchBlockedApps() async {
  final url = Uri.parse('${Config.baseUrl}/blocked-apps');

  try {
    final response = await http.get(url);
    logger.i('Response status: ${response.statusCode}');
    logger.i('Raw Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      logger.i('Decoded data: $data');

      if (data == null) {
        logger.e('Response data is null.');
        return [];
      }

      if (data['success'] != true) {
        logger.e('Success field is false: ${data['message']}');
        return [];
      }

      if (data['apps'] == null || data['apps'] is! List) {
        logger.e('Invalid "apps" field in response: ${data['apps']}');
        return [];
      }

      List<String> blockedApps = (data['apps'] as List)
          .map((app) => app['package_name'].toString())
          .toList();
      logger.i('Blocked apps retrieved: $blockedApps');
      return blockedApps;
    } else {
      logger.e('Failed to fetch blocked apps: ${response.statusCode} - ${response.reasonPhrase}');
    }
  } catch (error) {
    logger.e('Error fetching blocked apps: $error');
  }

  return [];
}

// Function to block a single app on the device using MethodChannel
Future<void> blockAppOnDevice(String packageName) async {
  try {
    await platform.invokeMethod('blockApp', {"packageName": packageName});
    logger.i("Successfully blocked app: $packageName");
  } catch (e) {
    logger.e("Failed to block app: $packageName, Error: $e");
    // Optionally log the stack trace
    logger.e("Stack trace: ${StackTrace.current}");
  }
}


  // Function to block all apps fetched from the backend
  Future<void> blockApps(List<String> blockedApps) async {
    for (String packageName in blockedApps) {
      await blockAppOnDevice(packageName);
    }
    logger.i('All blocked apps processed.');
  }

  // Function to fetch blocked apps and then block them on the device
  Future<void> fetchAndBlockApps() async {
    List<String> blockedApps = await fetchBlockedApps();
    if (blockedApps.isNotEmpty) {
      await blockApps(blockedApps);
      logger.i('Apps successfully blocked.');
    } else {
      logger.i('No apps to block.');
    }
  }
}
*/
/*
// filename: services/app_management_service.dart

import 'package:web_socket_channel/web_socket_channel.dart';
import 'config.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final Logger logger = Logger();

class AppManagementService {
  final WebSocketChannel _channel = WebSocketChannel.connect(
    Uri.parse(Config.websocketUrl),
  );

  AppManagementService() {
    // Listen to messages from WebSocket
    _channel.stream.listen((message) {
      logger.i('Received message from WebSocket: $message');
      final decodedMessage = jsonDecode(message);
      
      if (decodedMessage['action'] == 'blockApp') {
        String packageName = decodedMessage['packageName'];
        logger.i('Blocking app: $packageName');
        // Here you would implement logic to block the app on the device
        // based on the package name.
      }
    }, onError: (error) {
      logger.e('WebSocket error: $error');
    }, onDone: () {
      logger.i('WebSocket connection closed.');
    });
  }

  Future<void> blockAppsAndRunTimeManagement() async {
    try {
      logger.i('Calling blockAppsAndRunTimeManagement');
      _channel.sink.add('start_listener'); // Send command to WebSocket

      final url = Uri.parse('${Config.baseUrl}/block-and-run-management'); // Updated URL
      final response = await http.post(url);

      if (response.statusCode == 200) {
        logger.i('Apps blocked and time management executed successfully.');
      } else {
        logger.e('Failed to block apps or execute time management.');
      }
    } catch (error) {
      logger.e('Error in blockAppsAndRunTimeManagement: $error');
    }
  }

  void closeWebSocket() {
    _channel.sink.close();
  }
}

*/
/*
// filename: services/app_management_service.dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'config.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

final Logger logger = Logger();

class AppManagementService {
  final WebSocketChannel _channel = WebSocketChannel.connect(
    Uri.parse(Config.websocketUrl),
  );

  Future<void> blockAppsAndRunTimeManagement() async {
    try {
      // Send a message to the WebSocket server to start the blocking process
      _channel.sink.add('start_listener'); // Example of a command you might send

      final url = Uri.parse('${Config.baseUrl}/block-and-run-management'); // Updated URL
      final response = await http.post(url);

      if (response.statusCode == 200) {
        logger.i('Apps blocked and time management executed successfully.');
      } else {
        logger.e('Failed to block apps or execute time management.');
      }
    } catch (error) {
      logger.e('Error in blockAppsAndRunTimeManagement: $error');
    }
  }

  void closeWebSocket() {
    _channel.sink.close();
  }
}
*/
/*
import 'package:web_socket_channel/web_socket_channel.dart';
import 'config.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

final Logger logger = Logger();

class AppManagementService {
  final WebSocketChannel _channel = WebSocketChannel.connect(
    Uri.parse(Config.websocketUrl),
  );

  Future<void> blockAppsAndRunTimeManagement() async {
    try {
      // Send a message to the WebSocket server to start the blocking process
      _channel.sink.add('start_listener'); // Example of a command you might send

      final url = Uri.parse('${Config.baseUrl}/block-and-run-management'); // Updated URL
      final response = await http.post(url);

      if (response.statusCode == 200) {
        logger.i('Apps blocked and time management executed successfully.');
      } else {
        logger.e('Failed to block apps or execute time management.');
      }
    } catch (error) {
      logger.e('Error in blockAppsAndRunTimeManagement: $error');
    }
  }

  void closeWebSocket() {
    _channel.sink.close();
  }
}
*/