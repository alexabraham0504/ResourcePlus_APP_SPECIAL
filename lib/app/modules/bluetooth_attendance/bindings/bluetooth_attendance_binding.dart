// lib/app/modules/bluetooth_attendance/bindings/bluetooth_attendance_binding.dart

import 'package:get/get.dart';

import '../repositories/bluetooth_attendance_repository.dart';
import '../repositories/mock_bluetooth_attendance_repository.dart';
import '../repositories/api_bluetooth_attendance_repository.dart';
import '../config/bluetooth_attendance_config.dart';

class BluetoothAttendanceBinding extends Bindings {
  @override
  void dependencies() {
    // Inject the Repository
    Get.lazyPut<BluetoothAttendanceRepository>(() {
      if (BluetoothAttendanceConfig.demoMode) {
        return MockBluetoothAttendanceRepository();
      } else {
        return ApiBluetoothAttendanceRepository();
      }
    });

  }
}
