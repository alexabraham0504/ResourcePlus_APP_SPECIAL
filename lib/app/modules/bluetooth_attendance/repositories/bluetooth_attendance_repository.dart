// lib/app/modules/bluetooth_attendance/repositories/bluetooth_attendance_repository.dart

import '../models/bluetooth_attendance_challenge.dart';
import '../models/bluetooth_attendance_request.dart';
import '../config/bluetooth_attendance_config.dart';
import '../models/registered_device.dart';

abstract class BluetoothAttendanceRepository {
  /// Fetch authorized beacon configurations
  Future<List<BleBeaconConfig>> getBeaconConfiguration();

  /// Start a challenge to get a secure nonce
  Future<BluetoothAttendanceChallenge> startChallenge(String deviceId);

  /// Submit the attendance request
  Future<AttendanceResult> submitBluetoothAttendance(BluetoothAttendanceRequest request);

  /// Validates if a BLE device identifier is registered, and returns the associated Employee Name
  Future<String?> validateDevice(String deviceIdentifier);
  
  /// Registers a new BLE device for an employee
  Future<bool> registerDevice(RegisteredDevice device);
}

class AttendanceResult {
  final bool success;
  final String message;
  final bool requiresReview;

  AttendanceResult({
    required this.success,
    required this.message,
    this.requiresReview = false,
  });
}
