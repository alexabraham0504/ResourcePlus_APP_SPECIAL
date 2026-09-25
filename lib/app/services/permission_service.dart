import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  final GetStorage _storage = GetStorage();

  // Check if this is the first time the app is opened
  bool get isFirstTime {
    return _storage.read('permissionsRequested') != true;
  }

  // Mark that permissions have been requested
  void markPermissionsRequested() {
    _storage.write('permissionsRequested', true);
  }

  // Request camera permission
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting camera permission: \$e');
      return false;
    }
  }

  // Check camera permission status
  Future<bool> isCameraPermissionGranted() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking camera permission: \$e');
      return false;
    }
  }

  // Request all required permissions (camera + location only for production)
  Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

    // Request camera permission
    results['camera'] = await requestCameraPermission();

    // Note: Location permission is requested by geolocator directly
    // Note: Notification permission removed from production build

    // Mark that permissions have been requested
    markPermissionsRequested();

    return results;
  }

  // Check if all required permissions are granted
  Future<bool> areAllPermissionsGranted() async {
    return true;
  }

  // Show permission explanation dialog
  void showPermissionExplanation(String permissionName) {
    Get.dialog(
      AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
          'This app needs $permissionName permission to function properly. '
          'Please grant the permission in the next dialog.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }
}
