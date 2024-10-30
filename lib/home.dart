import 'package:flutter/material.dart';
import 'design/theme.dart';
import 'functions/device_info.dart';
import 'services/device_info_service.dart';
import 'services/app_list_service.dart';
import 'qr_code_screen.dart';
import 'main.dart';
import 'design/notification_prompts.dart';

class HomeScreen extends StatefulWidget {
  final String childId;

  const HomeScreen({super.key, required this.childId});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  final AppListService _appListService = AppListService();
  bool _showLoadingMessage = false; // New flag for loading message

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarColor = theme.appBarTheme.backgroundColor ?? Colors.green;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia';
    final buttonColor = theme.elevatedButtonTheme.style?.backgroundColor?.resolve({}) ?? Colors.green;

    return Scaffold(
      appBar: customAppBar(context, 'Home Screen', isLoggedIn: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                text: 'Allow ',
                style: TextStyle(
                  fontSize: 18.0,
                  color: textColor,
                  fontFamily: fontFamily,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: 'Famie',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: appBarColor,
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' to report this device\'s activity, which enables you to supervise your child\'s screen time.',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: textColor,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Text(
              'Allow Accessibility?',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  child: OutlinedButton(
                    onPressed: () {
                      showNoButtonPrompt(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: buttonColor,
                        width: 2.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    child: Text(
                      'No',
                      style: TextStyle(
                        fontSize: 16.0,
                        color: textColor,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: OutlinedButton(
                    onPressed: () async {
                      setState(() {
                        _showLoadingMessage = true; // Show loading message
                      });
                      await _handleAllowPressed();
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: buttonColor,
                      side: BorderSide(
                        color: buttonColor,
                        width: 2.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    child: const Text(
                      'Allow',
                      style: TextStyle(fontSize: 16.0, color: Colors.black, fontFamily: 'Georgia'),
                    ),
                  ),
                ),
              ],
            ),
            if (_showLoadingMessage) // Display the loading message
              Padding(
                padding: const EdgeInsets.only(top: 50),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: appBarColor, width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    'Please wait. This takes a few seconds.',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: textColor,
                      fontFamily: fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAllowPressed() async {
    if (!mounted) return;

    _deviceInfoService.logger.i('Allow button pressed');

    try {
      Map<String, String> deviceInfo = await getDeviceInfo();
      String deviceName = deviceInfo['deviceName']!;
      String macAddress = deviceInfo['macAddress']!;
      String androidId = deviceInfo['androidId']!;

      _deviceInfoService.logger.i('Device Info: $deviceName, $macAddress, $androidId');

      await _deviceInfoService.sendDeviceInfo(context, widget.childId, deviceName);

      List<Map<String, dynamic>> apps = await _appListService.getInstalledApps();
      List<Map<String, dynamic>> systemApps = apps.where((app) => app['isSystemApp'] == true).toList();
      List<Map<String, dynamic>> userApps = apps.where((app) => app['isSystemApp'] == false).toList();

      await _appListService.sendAppList(context, widget.childId, systemApps, userApps);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QrCodeScreen(
            childId: widget.childId,
            macAddress: macAddress,
            deviceName: deviceName,
            androidId: androidId,
          ),
        ),
      );
    } catch (error) {
      _deviceInfoService.logger.e('Error occurred during the process: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _showLoadingMessage = false; // Hide loading message
        });
      }
    }
  }

  void _logout(BuildContext context) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();



/*import 'package:flutter/material.dart';
import 'design/theme.dart';
import 'functions/device_info.dart'; // Your device info function
import 'services/device_info_service.dart';
import 'services/app_list_service.dart';
import 'qr_code_screen.dart';
import 'main.dart';
import 'design/notification_prompts.dart'; // Import the prompts

class HomeScreen extends StatefulWidget {
  final String childId;

  const HomeScreen({super.key, required this.childId}); // Accept the childId

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  final AppListService _appListService = AppListService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get the current theme
    final appBarColor = theme.appBarTheme.backgroundColor ?? Colors.green; // Get the AppBar color
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black; // Get the theme's text color
    final fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia'; // Get the theme's font style
    final buttonColor = theme.elevatedButtonTheme.style?.backgroundColor?.resolve({}) ?? Colors.green;

    return Scaffold(
      appBar: customAppBar(context, 'Home Screen', isLoggedIn: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily, // Follow theme font style
                color: textColor, // Follow theme text color
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                text: 'Allow ',
                style: TextStyle(
                  fontSize: 18.0,
                  color: textColor, // Follow theme text color
                  fontFamily: fontFamily, // Follow theme font style
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: 'Famie',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: appBarColor, // Use AppBar color
                      fontFamily: fontFamily, // Follow theme font style
                      fontWeight: FontWeight.bold, // Bold text for 'Famie'
                    ),
                  ),
                  TextSpan(
                    text: ' to report this device\'s activity, which enables you to supervise your child\'s screen time.',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: textColor, // Follow theme text color
                      fontFamily: fontFamily, // Follow theme font style
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Text(
              'Allow Accessibility?',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily, // Follow theme font style
                color: textColor, // Follow theme text color
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
              children: [
                SizedBox(
                  width: 120, // Set a fixed width for both buttons
                  child: OutlinedButton(
                    onPressed: () {
                      showNoButtonPrompt(context); // Display the prompt when No is clicked
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: buttonColor, // Use ElevatedButton's color for the border
                        width: 2.0, // Set the width of the border
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0), // Adjust padding
                    ),
                    child: Text(
                      'No',
                      style: TextStyle(
                        fontSize: 16.0,
                        color: textColor, // Follow theme text color
                        fontFamily: fontFamily, // Follow theme font style
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16), // Add spacing between buttons
                SizedBox(
                  width: 120, // Set the same width for both buttons
                  child: OutlinedButton(
                    onPressed: () async {
                      await _handleAllowPressed(); // Handle allow press
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: buttonColor, // Background color same as the elevated button
                      side: BorderSide(
                        color: buttonColor, // Use ElevatedButton's color for the border
                        width: 2.0, // Set the width of the border
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0), // Adjust padding
                    ),
                    child: const Text(
                      'Allow',
                      style: TextStyle(fontSize: 16.0, color: Colors.black, fontFamily: 'Georgia'), // Text in black
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAllowPressed() async {
    if (!mounted) return;

    _deviceInfoService.logger.i('Allow button pressed');

    try {
      // Get device info
      Map<String, String> deviceInfo = await getDeviceInfo(); // This function should return Android ID now
      String deviceName = deviceInfo['deviceName']!;
      String macAddress = deviceInfo['macAddress']!;
      String androidId = deviceInfo['androidId']!; // Add Android ID retrieval

      _deviceInfoService.logger.i('Device Info: $deviceName, $macAddress, $androidId');

      // Send device info to server
      await _deviceInfoService.sendDeviceInfo(context, widget.childId, deviceName);

      // Get installed apps and send them to server
      List<Map<String, dynamic>> apps = await _appListService.getInstalledApps();

      // Split the apps into system apps and user apps
      List<Map<String, dynamic>> systemApps = apps.where((app) => app['isSystemApp'] == true).toList();
      List<Map<String, dynamic>> userApps = apps.where((app) => app['isSystemApp'] == false).toList();

      // Send both system and user apps to the server
      await _appListService.sendAppList(context, widget.childId, systemApps, userApps);

      // Ensure the widget is still mounted before navigating
      if (!mounted) return;

      // Navigate to the QrCodeScreen, passing androidId as well
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QrCodeScreen(
            childId: widget.childId, // Pass childId when navigating
            macAddress: macAddress,
            deviceName: deviceName,
            androidId: androidId, // Pass Android ID
          ),
        ),
      );
    } catch (error) {
      _deviceInfoService.logger.e('Error occurred during the process: $error');
      // Handle the error, e.g., show a dialog or a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process: $error')),
        );
      }
    }
  }

  void _logout(BuildContext context) {
    if (!mounted) return; // Ensure widget is still mounted

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
*/
/*
import 'package:flutter/material.dart';
import 'design/theme.dart';
import 'functions/device_info.dart'; // Your device info function
import 'services/device_info_service.dart';
import 'services/app_list_service.dart';
import 'qr_code_screen.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  final String childId;

  const HomeScreen({super.key, required this.childId});  // Accept the childId

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  final AppListService _appListService = AppListService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Home Screen', isLoggedIn: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            RichText(
              text: const TextSpan(
                text: 'Allow ',
                style: TextStyle(
                  fontSize: 18.0,
                  color: Colors.black,
                  fontFamily: 'Georgia',
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: 'Famie',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.green,
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' to report this device\'s activity, which enables you to supervise your child\'s screen time.',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.black,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text(
              'Allow Accessibility!',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () {
                    _logout(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green[700]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30.0,
                      vertical: 15.0,
                    ),
                  ),
                  child: Text(
                    'No',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.green[700]!,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _deviceInfoService.logger.i('Allow button pressed');
                    Map<String, String> deviceInfo = await getDeviceInfo(); // This function should return Android ID now
                    String deviceName = deviceInfo['deviceName']!;
                    String macAddress = deviceInfo['macAddress']!;
                    String androidId = deviceInfo['androidId']!; // Add Android ID retrieval

                    _deviceInfoService.logger.i('Device Info: $deviceName, $macAddress, $androidId');

                    // Send device info to server
                    await _deviceInfoService.sendDeviceInfo(context, widget.childId, deviceName);

                    // Get installed apps and send them to server
                    List<Map<String, dynamic>> apps = await _appListService.getInstalledApps();

                    // Split the apps into system apps and user apps
                    List<Map<String, dynamic>> systemApps = apps.where((app) => app['isSystemApp'] == true).toList();
                    List<Map<String, dynamic>> userApps = apps.where((app) => app['isSystemApp'] == false).toList();

                    // Send both system and user apps to the server
                    await _appListService.sendAppList(context, widget.childId, systemApps, userApps);

                    if (!mounted) return; // Ensure widget is still mounted

                    // Navigate to the QrCodeScreen, passing androidId as well
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QrCodeScreen(
                          childId: widget.childId,  // Pass childId when navigating
                          macAddress: macAddress,
                          deviceName: deviceName,
                          androidId: androidId, // Pass Android ID
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
                  ),
                  child: const Text(
                    'Allow',
                    style: TextStyle(fontSize: 16.0, color: Colors.white, fontFamily: 'Georgia'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
*/
/*e update kay  naa nay system app and user app ang applist
import 'package:flutter/material.dart';
import 'design/theme.dart';
import 'functions/device_info.dart'; // Your device info function
import 'services/device_info_service.dart';
import 'services/app_list_service.dart';
import 'qr_code_screen.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  final String childId;

  const HomeScreen({super.key, required this.childId});  // Accept the childId

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  final AppListService _appListService = AppListService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Home Screen', isLoggedIn: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            RichText(
              text: const TextSpan(
                text: 'Allow ',
                style: TextStyle(
                  fontSize: 18.0,
                  color: Colors.black,
                  fontFamily: 'Georgia',
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: 'Famie',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.green,
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' to report this device\'s activity, which enables you to supervise your child\'s screen time.',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.black,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text(
              'Allow Accessibility!',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () {
                    _logout(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green[700]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30.0,
                      vertical: 15.0,
                    ),
                  ),
                  child: Text(
                    'No',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.green[700]!,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _deviceInfoService.logger.i('Allow button pressed');
                    Map<String, String> deviceInfo = await getDeviceInfo(); // This function should return Android ID now
                    String deviceName = deviceInfo['deviceName']!;
                    String macAddress = deviceInfo['macAddress']!;
                    String androidId = deviceInfo['androidId']!; // Add Android ID retrieval

                    _deviceInfoService.logger.i('Device Info: $deviceName, $macAddress, $androidId');

                    // Send device info to server
                    await _deviceInfoService.sendDeviceInfo(context, widget.childId, deviceName);

                    // Get installed apps and send them to server
                    List<Map<String, dynamic>> apps = await _appListService.getInstalledApps();
                    await _appListService.sendAppList(context, widget.childId, apps);

                    if (!mounted) return; // Ensure widget is still mounted

                    // Navigate to the QrCodeScreen, passing androidId as well
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QrCodeScreen(
                          childId: widget.childId,  // Pass childId when navigating
                          macAddress: macAddress,
                          deviceName: deviceName,
                          androidId: androidId, // Pass Android ID
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
                  ),
                  child: const Text(
                    'Allow',
                    style: TextStyle(fontSize: 16.0, color: Colors.white, fontFamily: 'Georgia'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
*/
/*
import 'package:flutter/material.dart';
import 'design/theme.dart';
import 'functions/device_info.dart'; 
import 'services/device_info_service.dart';
import 'services/app_list_service.dart';
import 'qr_code_screen.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  final String childId;

  const HomeScreen({super.key, required this.childId});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  final AppListService _appListService = AppListService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Home Screen', isLoggedIn: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            RichText(
              text: const TextSpan(
                text: 'Allow ',
                style: TextStyle(
                  fontSize: 18.0,
                  color: Colors.black,
                  fontFamily: 'Georgia',
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: 'Famie',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.green,
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' to report this device\'s activity, which enables you to supervise your child\'s screen time.',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.black,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text(
              'Allow Accessibility!',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () {
                    _logout(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green[700]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30.0,
                      vertical: 15.0),
                  ),
                  child: Text(
                    'No',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.green[700]!,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _deviceInfoService.logger.i('Allow button pressed');
                    Map<String, String> deviceInfo = await getDeviceInfo();
                    String deviceName = deviceInfo['deviceName']!;
                    String macAddress = deviceInfo['macAddress']!;
                    _deviceInfoService.logger.i('Device Info: $deviceName, $macAddress');

                    // Send device info to server
                    await _deviceInfoService.sendDeviceInfo(context, widget.childId, deviceName, macAddress);

                    // Get installed apps and send them to server
                    List<Map<String, dynamic>> apps = await _appListService.getInstalledApps();
                    await _appListService.sendAppList(context, widget.childId, apps);

                    if (!mounted) return; // Ensure widget is still mounted
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QrCodeScreen(
                          macAddress: macAddress,
                          deviceName: deviceName,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
                  ),
                  child: const Text(
                    'Allow',
                    style: TextStyle(fontSize: 16.0, color: Colors.white, fontFamily: 'Georgia'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
*/