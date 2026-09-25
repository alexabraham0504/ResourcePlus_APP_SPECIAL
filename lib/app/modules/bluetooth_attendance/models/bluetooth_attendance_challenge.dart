// lib/app/modules/bluetooth_attendance/models/bluetooth_attendance_challenge.dart

class BluetoothAttendanceChallenge {
  final String challengeId;
  final String nonce;
  final DateTime expiresAt;

  BluetoothAttendanceChallenge({
    required this.challengeId,
    required this.nonce,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
