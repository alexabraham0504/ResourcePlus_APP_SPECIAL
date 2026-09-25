class FaceEnrollmentRequest {
  final String employeeId;
  final List<String> base64Samples; // Base64 encoded images
  final String requestId;

  FaceEnrollmentRequest({
    required this.employeeId,
    required this.base64Samples,
    required this.requestId,
  });

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'samples': base64Samples,
      'requestId': requestId,
    };
  }
}
