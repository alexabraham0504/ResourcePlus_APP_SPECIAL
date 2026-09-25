class RegisteredDevice {
  final String employeeId;
  final String employeeName;
  final String deviceIdentifier;
  final DateTime registeredAt;
  final String status;

  RegisteredDevice({
    required this.employeeId,
    required this.employeeName,
    required this.deviceIdentifier,
    required this.registeredAt,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'deviceIdentifier': deviceIdentifier,
      'registeredAt': registeredAt.toIso8601String(),
      'status': status,
    };
  }

  factory RegisteredDevice.fromJson(Map<String, dynamic> json) {
    return RegisteredDevice(
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      deviceIdentifier: json['deviceIdentifier'] ?? '',
      registeredAt: DateTime.parse(json['registeredAt']),
      status: json['status'] ?? 'Active',
    );
  }
}
