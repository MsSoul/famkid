// filename: qr_code_screen.dart
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/qrcode_service.dart';
import 'design/notification_prompts.dart';
import 'protection_screen.dart';
import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'design/theme.dart';

class QrCodeScreen extends StatefulWidget {
  String macAddress;
  String deviceName;
  String androidId;
  final String childId;

  QrCodeScreen({
    super.key,
    required this.macAddress,
    required this.deviceName,
    required this.androidId,
    required this.childId,
  });

  @override
  QrCodeScreenState createState() => QrCodeScreenState();
}

class QrCodeScreenState extends State<QrCodeScreen> {
  late String svgData;
  bool isLoading = true;
  bool connectionSuccessful = false;
  final QrCodeService _qrCodeService = QrCodeService();
  final Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchDeviceInfo();
    _generateSvg();
    _startPollingForProfileMatch();
  }

  // Fetch MAC Address, Device Info, and Android ID
  Future<void> _fetchDeviceInfo() async {
    String? macAddress = await getMacAddress();
    String deviceName = await getDeviceName();
    String androidId = await getAndroidId();

    setState(() {
      widget.macAddress = macAddress ?? "Unknown";
      widget.deviceName = deviceName;
      widget.androidId = androidId;
    });

    logger.i("Fetched MAC Address: $macAddress");
    logger.i("Fetched Device Name: $deviceName");
    logger.i("Fetched Android ID: $androidId");
  }

  // Retrieve the MAC address using connectivity checks
  Future<String?> getMacAddress() async {
    String macAddress = 'Unknown';
    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.wifi) {
      // MAC retrieval blocked on Android 10+
      macAddress = 'Wi-Fi connected, MAC retrieval blocked on Android 10+';
    } else {
      macAddress = 'No Wi-Fi connection';
    }

    return macAddress;
  }

  // Retrieve the device name using device_info_plus
  Future<String> getDeviceName() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.model ?? "Unknown Device";
  }

  // Retrieve the Android ID using device_info_plus
  Future<String> getAndroidId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id ?? "Unknown Android ID";
  }

  // Generate the QR code SVG
// Generate the QR code SVG with black color
void _generateSvg() {
  final qrData =
      '{"macAddress": "${widget.macAddress}", "deviceName": "${widget.deviceName}", "androidId": "${widget.androidId}", "childId": "${widget.childId}"}';
  logger.i("QR Code Data: $qrData");

  final qrCode = Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.high);
  svgData = qrCode.toSvg(
    qrData,
    width: 300,
    height: 300,
    color: 0xFF000000, // Use black color for the QR code
  );

  setState(() {
    isLoading = false;
  });
}

  // Polling for profile match
  void _startPollingForProfileMatch() {
    _qrCodeService.startPollingForChildProfile(
      widget.childId,
      widget.deviceName,
      _onProfileMatchSuccess,
    );
  }

  // Callback when the profile match is successful
  void _onProfileMatchSuccess() {
    setState(() {
      connectionSuccessful = true;
    });
    showConnectionSuccessPrompt(context, widget.childId); // Pass childId here
  }

  @override
  void dispose() {
    _qrCodeService.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get the current theme
    final appBarColor = theme.appBarTheme.backgroundColor ?? Colors.green; // Get the AppBar color
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black; // Get the theme's text color
    final fontFamily = theme.textTheme.bodyLarge?.fontFamily ?? 'Georgia'; // Get the theme's font style
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = screenWidth * 0.7;

    return Scaffold(
      appBar: customAppBar(context, 'QR Code'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9.0, top: 12.0),
                      child: Text(
                        'Create your child\'s profile by scanning this',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          fontFamily: fontFamily, // Follow theme font style
                          color: textColor, // Follow theme text color
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text(
                      'QR Code',
                      style: TextStyle(
                        fontSize: 40.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily, // Follow theme font style
                        color: appBarColor, // Use AppBar color
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16.0),
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: appBarColor, // Use AppBar color for border
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: SvgPicture.string(
                              svgData,
                              width: qrSize,
                              height: qrSize,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2.0),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 70,
                              height: 70,
                              color: Colors.white,
                              child: Center(
                                child: Image.asset(
                                  'assets/famie_icon-removebg-preview.png',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Device Name',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily, // Follow theme font style
                        color: textColor, // Follow theme text color
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.deviceName,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontFamily: fontFamily, // Follow theme font style
                        fontWeight: FontWeight.bold,
                        color: appBarColor, // Use AppBar color
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Android ID',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily, // Follow theme font style
                        color: textColor, // Follow theme text color
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.androidId,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontFamily: fontFamily, // Follow theme font style
                        fontWeight: FontWeight.bold,
                        color: appBarColor, // Use AppBar color
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (connectionSuccessful)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => ProtectionScreen(childId: widget.childId),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        },
                        style: theme.elevatedButtonTheme.style, // Use the elevated button style from theme
                      child: Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white, // Use the theme's text color
                            fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily ?? 'Georgia', // Use the theme's font style
                          ),
                        ),

                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/*
// filename: qr_code_screen.dart
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/qrcode_service.dart';
import 'design/notification_prompts.dart';
import 'protection_screen.dart';
import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'design/theme.dart';

class QrCodeScreen extends StatefulWidget {
  String macAddress;
  String deviceName;
  String androidId;
  final String childId;

  QrCodeScreen({
    super.key,
    required this.macAddress,
    required this.deviceName,
    required this.androidId,
    required this.childId,
  });

  @override
  QrCodeScreenState createState() => QrCodeScreenState();
}

class QrCodeScreenState extends State<QrCodeScreen> {
  late String svgData;
  bool isLoading = true;
  bool connectionSuccessful = false;
  final QrCodeService _qrCodeService = QrCodeService();
  final Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchDeviceInfo();
    _generateSvg();
    _startPollingForProfileMatch();
  }

  // Fetch MAC Address, Device Info, and Android ID
  Future<void> _fetchDeviceInfo() async {
    String? macAddress = await getMacAddress();
    String deviceName = await getDeviceName();
    String androidId = await getAndroidId();

    setState(() {
      widget.macAddress = macAddress ?? "Unknown";
      widget.deviceName = deviceName;
      widget.androidId = androidId;
    });

    logger.i("Fetched MAC Address: $macAddress");
    logger.i("Fetched Device Name: $deviceName");
    logger.i("Fetched Android ID: $androidId");
  }

  // Retrieve the MAC address using connectivity checks
  Future<String?> getMacAddress() async {
    String macAddress = 'Unknown';
    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.wifi) {
      // MAC retrieval blocked on Android 10+
      macAddress = 'Wi-Fi connected, MAC retrieval blocked on Android 10+';
    } else {
      macAddress = 'No Wi-Fi connection';
    }

    return macAddress;
  }

  // Retrieve the device name using device_info_plus
  Future<String> getDeviceName() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.model ?? "Unknown Device";
  }

  // Retrieve the Android ID using device_info_plus
  Future<String> getAndroidId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id ?? "Unknown Android ID";
  }

  // Generate the QR code SVG
  void _generateSvg() {
    final qrData =
        '{"macAddress": "${widget.macAddress}", "deviceName": "${widget.deviceName}", "androidId": "${widget.androidId}", "childId": "${widget.childId}"}';
    logger.i("QR Code Data: $qrData");

    final qrCode = Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.high);
    svgData = qrCode.toSvg(qrData, width: 300, height: 300, color: 0xFF388E3C);
    setState(() {
      isLoading = false;
    });
  }

  // Polling for profile match
  void _startPollingForProfileMatch() {
    _qrCodeService.startPollingForChildProfile(
      widget.childId,
      widget.deviceName,
      _onProfileMatchSuccess,
    );
  }

  // Callback when the profile match is successful
  void _onProfileMatchSuccess() {
    setState(() {
      connectionSuccessful = true;
    });
    showConnectionSuccessPrompt(context, widget.childId); // Pass childId here
  }

  @override
  void dispose() {
    _qrCodeService.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = screenWidth * 0.7;

    return Scaffold(
      appBar: customAppBar(context, 'QR Code'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 9.0, top: 16.0),
                      child: Text(
                        'Create your child\'s profile by scanning this',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Text(
                      'QR Code',
                      style: TextStyle(
                        fontSize: 40.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Color(0xFF388E3C),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16.0),
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF388E3C),
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: SvgPicture.string(
                              svgData,
                              width: qrSize,
                              height: qrSize,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2.0),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 70,
                              height: 70,
                              color: Colors.white,
                              child: Center(
                                child: Image.asset(
                                  'assets/famie_icon-removebg-preview.png',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Device Name',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.deviceName,
                      style: const TextStyle(
                        fontSize: 22.0,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF388E3C),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Android ID',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.androidId,
                      style: const TextStyle(
                        fontSize: 22.0,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF388E3C),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (connectionSuccessful)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => ProtectionScreen(childId: widget.childId),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.white,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
*/
/*
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/qrcode_service.dart';
import 'design/notification_prompts.dart';
import 'protection_screen.dart';
import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'design/theme.dart';

class QrCodeScreen extends StatefulWidget {
  String macAddress;
  String deviceName;
  String androidId;
  final String childId;

  QrCodeScreen({
    super.key,
    required this.macAddress,
    required this.deviceName,
    required this.androidId,
    required this.childId,
  });

  @override
  QrCodeScreenState createState() => QrCodeScreenState();
}

class QrCodeScreenState extends State<QrCodeScreen> {
  late String svgData;
  bool isLoading = true;
  bool connectionSuccessful = false;
  final QrCodeService _qrCodeService = QrCodeService();
  final Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchDeviceInfo();
    _generateSvg();
    _startPollingForProfileMatch();
  }

  // Fetch MAC Address, Device Info, and Android ID
  Future<void> _fetchDeviceInfo() async {
    String? macAddress = await getMacAddress();
    String deviceName = await getDeviceName();
    String androidId = await getAndroidId();

    setState(() {
      widget.macAddress = macAddress ?? "Unknown";
      widget.deviceName = deviceName;
      widget.androidId = androidId;
    });

    logger.i("Fetched MAC Address: $macAddress");
    logger.i("Fetched Device Name: $deviceName");
    logger.i("Fetched Android ID: $androidId");
  }

  // Retrieve the MAC address using connectivity checks
  Future<String?> getMacAddress() async {
    String macAddress = 'Unknown';
    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.wifi) {
      // MAC retrieval blocked on Android 10+
      macAddress = 'Wi-Fi connected, MAC retrieval blocked on Android 10+';
    } else {
      macAddress = 'No Wi-Fi connection';
    }

    return macAddress;
  }

  // Retrieve the device name using device_info_plus
  Future<String> getDeviceName() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.model ?? "Unknown Device";
  }

  // Retrieve the Android ID using device_info_plus
  Future<String> getAndroidId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id ?? "Unknown Android ID";
  }

  // Generate the QR code SVG
  void _generateSvg() {
    final qrData =
        '{"macAddress": "${widget.macAddress}", "deviceName": "${widget.deviceName}", "androidId": "${widget.androidId}", "childId": "${widget.childId}"}';
    logger.i("QR Code Data: $qrData");

    final qrCode = Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.high);
    svgData = qrCode.toSvg(qrData, width: 300, height: 300, color: 0xFF388E3C);
    setState(() {
      isLoading = false;
    });
  }

  // Polling for profile match
  void _startPollingForProfileMatch() {
    _qrCodeService.startPollingForChildProfile(
      widget.childId,
      widget.deviceName,
      _onProfileMatchSuccess,
    );
  }

  // Callback when the profile match is successful
  void _onProfileMatchSuccess() {
    setState(() {
      connectionSuccessful = true;
    });
    showConnectionSuccessPrompt(context);
  }

  // Navigate to the ProtectionScreen
  void _navigateToProtectionScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const ProtectionScreen(context, widget.childId)),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    _qrCodeService.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = screenWidth * 0.7;

    return Scaffold(
      appBar: customAppBar(context, 'QR Code'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 9.0, top: 16.0),
                      child: Text(
                        'Create your child\'s profile by scanning this',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Text(
                      'QR Code',
                      style: TextStyle(
                        fontSize: 40.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Color(0xFF388E3C),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16.0),
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF388E3C),
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: SvgPicture.string(
                              svgData,
                              width: qrSize,
                              height: qrSize,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2.0),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 70,
                              height: 70,
                              color: Colors.white,
                              child: Center(
                                child: Image.asset(
                                  'assets/famie_icon.png',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Device Name',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.deviceName,
                      style: const TextStyle(
                        fontSize: 22.0,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF388E3C),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Android ID',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.androidId,
                      style: const TextStyle(
                        fontSize: 22.0,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF388E3C),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (connectionSuccessful)
                      ElevatedButton(
                        onPressed: _navigateToProtectionScreen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.white,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
*/

/*tangaglon na nag wifi info flutter
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/qrcode_service.dart'; // Import the QrCodeService
import 'design/notification_prompts.dart'; // Import your notification prompts
import 'protection_screen.dart'; // Import the ProtectionScreen for navigation
import 'package:logger/logger.dart';
import 'package:wifi_info_flutter/wifi_info_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'design/theme.dart'; // Import customAppBar

class QrCodeScreen extends StatefulWidget {
  String macAddress;
  String deviceName; // Set deviceName as mutable
  final String childId;

  QrCodeScreen({
    super.key,
    required this.macAddress,
    required this.deviceName,
    required this.childId,
  });

  @override
  QrCodeScreenState createState() => QrCodeScreenState();
}

class QrCodeScreenState extends State<QrCodeScreen> {
  late String svgData;
  bool isLoading = true;
  bool connectionSuccessful = false; // Variable to track connection success
  final QrCodeService _qrCodeService = QrCodeService(); // Initialize _qrCodeService
  final Logger logger = Logger(); // Initialize Logger

  @override
  void initState() {
    super.initState();
    _fetchDeviceInfo();
    _generateSvg();
    _startPollingForProfileMatch(); // Start polling for profile match
  }

  // Fetch MAC Address and Device Info
  Future<void> _fetchDeviceInfo() async {
    String? macAddress = await getMacAddress();
    String deviceName = await getDeviceName();

    setState(() {
      widget.macAddress = macAddress ?? "Unknown";
      widget.deviceName = deviceName;
    });
    
    logger.i("Fetched MAC Address: $macAddress");
    logger.i("Fetched Device Name: $deviceName");
  }

  // Retrieve MAC address using wifi_info_flutter
  Future<String?> getMacAddress() async {
    String? macAddress;
    try {
      macAddress = await WifiInfo().getWifiBSSID(); // Get MAC address of the Wi-Fi connected
    } catch (e) {
      macAddress = "Unknown";
    }
    return macAddress;
  }

  // Retrieve the device name using device_info_plus
  Future<String> getDeviceName() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.model ?? "Unknown Device";
  }

  // Generate the QR code SVG
void _generateSvg() {
  final qrData =
      '{"macAddress": "${widget.macAddress}", "deviceName": "${widget.deviceName}", "childId": "${widget.childId}"}';
  logger.i("QR Code Data: $qrData");  // Log the QR code data
  
  final qrCode = Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.high);
  svgData = qrCode.toSvg(qrData, width: 300, height: 300, color: 0xFF388E3C); // Generate the QR code
  setState(() {
    isLoading = false;
  });
}

  // Polling for profile match
  void _startPollingForProfileMatch() {
    _qrCodeService.startPollingForChildProfile(
      widget.childId,
      widget.deviceName,
      _onProfileMatchSuccess,
    );
  }

  // Callback when the profile match is successful
  void _onProfileMatchSuccess() {
    setState(() {
      connectionSuccessful = true; // Set the connection as successful
    });
    showConnectionSuccessPrompt(context); // Show the notification prompt
  }

  // Navigate to the ProtectionScreen
  void _navigateToProtectionScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const ProtectionScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    _qrCodeService.stopPolling(); // Stop polling when the screen is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate dynamic width for QR code and its box
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = screenWidth * 0.7; // Set QR size to 70% of screen width
    
    return Scaffold(
      appBar: customAppBar(context, 'QR Code'), // Use the customAppBar
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.start, // Move items to the top
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 9.0, top: 16.0),
                      child: Text(
                        'Create your child\'s profile by scanning this',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Text(
                      'QR Code',
                      style: TextStyle(
                        fontSize: 40.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Color(0xFF388E3C), 
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16.0), 
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF388E3C),
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: SvgPicture.string(
                              svgData,
                              width: qrSize,
                              height: qrSize,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2.0),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 70,
                              height: 70,
                              color: Colors.white,
                              child: Center(
                                child: Image.asset(
                                  'assets/famie_icon.png',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Device Name', 
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.deviceName,
                      style: const TextStyle(
                        fontSize: 22.0,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF388E3C),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (connectionSuccessful)
                      ElevatedButton(
                        onPressed: _navigateToProtectionScreen, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[200], 
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.white,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
*/
/*
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/qrcode_service.dart'; // Import the QrCodeService
import 'design/notification_prompts.dart'; // Import your notification prompts
import 'protection_screen.dart'; // Import the ProtectionScreen for navigation
import 'package:logger/logger.dart';
import 'package:wifi_info_flutter/wifi_info_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

class QrCodeScreen extends StatefulWidget {
  String macAddress;
  String deviceName; // Set deviceName as mutable
  final String childId;

  QrCodeScreen({
    super.key,
    required this.macAddress,
    required this.deviceName,
    required this.childId,
  });

  @override
  QrCodeScreenState createState() => QrCodeScreenState();
}

class QrCodeScreenState extends State<QrCodeScreen> {
  late String svgData;
  bool isLoading = true;
  bool connectionSuccessful = false; // Variable to track connection success
  final QrCodeService _qrCodeService = QrCodeService(); // Initialize _qrCodeService
  final Logger logger = Logger(); // Initialize Logger

  @override
  void initState() {
    super.initState();
    _fetchDeviceInfo();
    _generateSvg();
    _startPollingForProfileMatch(); // Start polling for profile match
  }

  // Fetch MAC Address and Device Info
  Future<void> _fetchDeviceInfo() async {
    String? macAddress = await getMacAddress();
    String deviceName = await getDeviceName();

    setState(() {
      widget.macAddress = macAddress ?? "Unknown";
      widget.deviceName = deviceName;
    });
    
    logger.i("Fetched MAC Address: $macAddress");
    logger.i("Fetched Device Name: $deviceName");
  }

  // Retrieve MAC address using wifi_info_flutter
  Future<String?> getMacAddress() async {
    String? macAddress;
    try {
      macAddress = await WifiInfo().getWifiBSSID(); // Get MAC address of the Wi-Fi connected
    } catch (e) {
      macAddress = "Unknown";
    }
    return macAddress;
  }

  // Retrieve the device name using device_info_plus
  Future<String> getDeviceName() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.model ?? "Unknown Device";
  }

  // Generate the QR code SVG
void _generateSvg() {
  final qrData =
      '{"macAddress": "${widget.macAddress}", "deviceName": "${widget.deviceName}", "childId": "${widget.childId}"}';
  logger.i("QR Code Data: $qrData");  // Log the QR code data
  
  final qrCode = Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.high);
  svgData = qrCode.toSvg(qrData, width: 300, height: 300, color: 0xFF388E3C); // Generate the QR code
  setState(() {
    isLoading = false;
  });
}

  // Polling for profile match
  void _startPollingForProfileMatch() {
    _qrCodeService.startPollingForChildProfile(
      widget.childId,
      widget.deviceName,
      _onProfileMatchSuccess,
    );
  }

  // Callback when the profile match is successful
  void _onProfileMatchSuccess() {
    setState(() {
      connectionSuccessful = true; // Set the connection as successful
    });
    showConnectionSuccessPrompt(context); // Show the notification prompt
  }

  // Navigate to the ProtectionScreen
  void _navigateToProtectionScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const ProtectionScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    _qrCodeService.stopPolling(); // Stop polling when the screen is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate dynamic width for QR code and its box
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = screenWidth * 0.7; // Set QR size to 70% of screen width
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.start, // Move items to the top
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 9.0, top: 16.0),
                      child: Text(
                        'Create your child\'s profile by scanning this',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Text(
                      'QR Code',
                      style: TextStyle(
                        fontSize: 40.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Color(0xFF388E3C), 
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16.0), 
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF388E3C),
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: SvgPicture.string(
                              svgData,
                              width: qrSize,
                              height: qrSize,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2.0),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 70,
                              height: 70,
                              color: Colors.white,
                              child: Center(
                                child: Image.asset(
                                  'assets/famie_icon.png',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Device Name', 
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.deviceName,
                      style: const TextStyle(
                        fontSize: 22.0,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF388E3C),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (connectionSuccessful)
                      ElevatedButton(
                        onPressed: _navigateToProtectionScreen, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[200], 
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.white,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
*/
/*
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/qrcode_service.dart'; // Import the QrCodeService
import 'design/notification_prompts.dart'; // Import your notification prompts
import 'protection_screen.dart'; // Import the ProtectionScreen for navigation
import 'package:logger/logger.dart'; 

class QrCodeScreen extends StatefulWidget {
  final String macAddress;
  final String deviceName; // Keep the original deviceName parameter
  final String childId;

  const QrCodeScreen({
    super.key,
    required this.macAddress,
    required this.deviceName,
    required this.childId,
  });

  @override
  QrCodeScreenState createState() => QrCodeScreenState();
}

class QrCodeScreenState extends State<QrCodeScreen> {
  late String svgData;
  bool isLoading = true;
  bool connectionSuccessful = false; // Variable to track connection success
  final QrCodeService _qrCodeService = QrCodeService(); // Initialize _qrCodeService
  final Logger logger = Logger(); // Initialize Logger

  @override
  void initState() {
    super.initState();
    _generateSvg();
    _startPollingForProfileMatch(); // Start polling for profile match
  }

  // Generate the QR code SVG
  void _generateSvg() {
    final qrData =
        '{"macAddress": "${widget.macAddress}", "deviceName": "${widget.deviceName}", "child_id": "${widget.childId}"}'; 
    
    final qrCode = Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.high);
    svgData = qrCode.toSvg(qrData, width: 300, height: 300, color: 0xFF388E3C); // Generate the QR code
    setState(() {
      isLoading = false;
    });
  }

  // Polling for profile match
  void _startPollingForProfileMatch() {
    _qrCodeService.startPollingForChildProfile(
      widget.childId,
      widget.deviceName,
      _onProfileMatchSuccess,
    );
  }

  // Callback when the profile match is successful
  void _onProfileMatchSuccess() {
    setState(() {
      connectionSuccessful = true; // Set the connection as successful
    });
    showConnectionSuccessPrompt(context); // Show the notification prompt
  }

  // Navigate to the ProtectionScreen
  void _navigateToProtectionScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const ProtectionScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    _qrCodeService.stopPolling(); // Stop polling when the screen is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate dynamic width for QR code and its box
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = screenWidth * 0.7; // Set QR size to 70% of screen width
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.start, // Move items to the top
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 9.0, top: 16.0),
                      child: Text(
                        'Create your child\'s profile by scanning this',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Text(
                      'QR Code',
                      style: TextStyle(
                        fontSize: 40.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Color(0xFF388E3C), 
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16.0), 
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF388E3C),
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: SvgPicture.string(
                              svgData,
                              width: qrSize,
                              height: qrSize,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2.0),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 70,
                              height: 70,
                              color: Colors.white,
                              child: Center(
                                child: Image.asset(
                                  'assets/famie_icon.png',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Device Name', 
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.deviceName,
                      style: const TextStyle(
                        fontSize: 22.0,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF388E3C),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (connectionSuccessful)
                      ElevatedButton(
                        onPressed: _navigateToProtectionScreen, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[200], 
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.white,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
*/