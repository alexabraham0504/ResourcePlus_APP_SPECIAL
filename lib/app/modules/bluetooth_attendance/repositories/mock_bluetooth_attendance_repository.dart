// lib/app/modules/bluetooth_attendance/repositories/mock_bluetooth_attendance_repository.dart

import 'dart:math';
import '../models/bluetooth_attendance_challenge.dart';
import '../models/bluetooth_attendance_request.dart';
import '../config/bluetooth_attendance_config.dart';
import 'bluetooth_attendance_repository.dart';
import '../models/registered_device.dart';
import 'host_device_registry.dart';

class MockBluetoothAttendanceRepository implements BluetoothAttendanceRepository {
  @override
  Future<List<BleBeaconConfig>> getBeaconConfiguration() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (BluetoothAttendanceConfig.activeScenario == MockScenario.demoNetworkError) {
      throw Exception('Mock network error fetching configuration');
    }

    return BluetoothAttendanceConfig.authorizedBeacons;
  }

  @override
  Future<BluetoothAttendanceChallenge> startChallenge(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    return BluetoothAttendanceChallenge(
      challengeId: 'MOCK-CHAL-${DateTime.now().millisecondsSinceEpoch}',
      nonce: _generateMockNonce(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<AttendanceResult> submitBluetoothAttendance(BluetoothAttendanceRequest request) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate server processing

    switch (BluetoothAttendanceConfig.activeScenario) {
      case MockScenario.demoSuccess:
        return AttendanceResult(success: true, message: 'Attendance marked successfully');
      
      case MockScenario.demoRejectedBeacon:
        return AttendanceResult(success: false, message: 'Unauthorized beacon detected');
      
      case MockScenario.demoWeakProximity:
        return AttendanceResult(success: false, message: 'You are too far from the beacon (-85 dBm)');
      
      case MockScenario.demoLocationFailed:
        return AttendanceResult(success: false, message: 'Location out of bounds');
      
      case MockScenario.demoDuplicate:
        return AttendanceResult(success: false, message: 'Attendance already marked for this shift');
      
      case MockScenario.demoNetworkError:
        throw Exception('Mock network connection lost');
      
      case MockScenario.demoReview:
        return AttendanceResult(success: true, message: 'Attendance submitted for manual review', requiresReview: true);
    }
  }

  @override
  Future<String?> validateDevice(String deviceIdentifier) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Check against our local mock "database" (HostDeviceRegistry)
    final registry = HostDeviceRegistry.getRegisteredDevices();
    if (registry.containsKey(deviceIdentifier)) {
      return registry[deviceIdentifier]!.employeeName;
    }
    
    return null; // Not registered
  }
  
  @override
  Future<bool> registerDevice(RegisteredDevice device) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Save to our local mock "database"
    await HostDeviceRegistry.registerDevice(device);
    return true;
  }

  String _generateMockNonce() {
    final random = Random();
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }
}
