// lib/app/modules/bluetooth_attendance/models/bluetooth_attendance_request.dart

import 'dart:typed_data';

class BluetoothAttendanceRequest {
  final String attendanceType; // 'I' or 'O'
  final String requestId;
  final String? challengeId;
  final BleEvidence beacon;
  final LocationEvidence location;
  final DeviceEvidence device;
  final Uint8List selfieBytes;

  BluetoothAttendanceRequest({
    required this.attendanceType,
    required this.requestId,
    this.challengeId,
    required this.beacon,
    required this.location,
    required this.device,
    required this.selfieBytes,
  });
}

class BleEvidence {
  final String beaconId;
  final String uuid;
  final int major;
  final int minor;
  final int bestRssi;
  final double averageRssi;
  final int sampleCount;
  final DateTime firstSeen;
  final DateTime lastSeen;

  BleEvidence({
    required this.beaconId,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.bestRssi,
    required this.averageRssi,
    required this.sampleCount,
    required this.firstSeen,
    required this.lastSeen,
  });
}

class LocationEvidence {
  final double latitude;
  final double longitude;
  final double accuracy;

  LocationEvidence({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}

class DeviceEvidence {
  final String deviceId;
  final String platform;
  final String appVersion;
  final String localTime;
  final String timeZone;

  DeviceEvidence({
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    required this.localTime,
    required this.timeZone,
  });
}
