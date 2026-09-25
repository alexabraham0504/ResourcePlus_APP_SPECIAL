import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoHelper {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static Future<String> getPermanentDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        return androidInfo.id; // Unique hardware ID on Android
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        return iosInfo.identifierForVendor ?? 'UNKNOWN_IOS_DEVICE'; // Vendor ID on iOS
      }
    } catch (e) {
      // Fallback in case of an error
    }
    return 'UNKNOWN_DEVICE';
  }
}
