class FaceVerificationRequest {
  final String attendanceType; // CHECK_IN or CHECK_OUT
  final String challengeId;
  final String requestId;
  final String faceEvidence; // Base64 encoded image
  final String livenessEvidence; // Details about the liveness challenge completed
  final String deviceMetadata; // "HardwareID|DeviceName|UTC|Local|Timezone"

  FaceVerificationRequest({
    required this.attendanceType,
    required this.challengeId,
    required this.requestId,
    required this.faceEvidence,
    required this.livenessEvidence,
    required this.deviceMetadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'attendanceType': attendanceType,
      'challengeId': challengeId,
      'requestId': requestId,
      'faceEvidence': faceEvidence,
      'livenessEvidence': livenessEvidence,
      'deviceMetadata': deviceMetadata,
    };
  }
}
