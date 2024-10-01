import 'package:permission_handler/permission_handler.dart';

Future<void> requestStoragePermission() async {
  if (await Permission.storage.request().isGranted) {
    // Access files here
  } else {
    // Permission denied, show an error message or handle accordingly
  }
}
