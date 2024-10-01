// filename: home.dart
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