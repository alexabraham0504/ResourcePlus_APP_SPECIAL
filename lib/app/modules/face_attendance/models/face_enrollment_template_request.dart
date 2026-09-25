// lib/app/modules/face_attendance/models/face_enrollment_template_request.dart
//
// Payload sent to backend for face enrollment.
// The backend stores the template as a JSON string for now.
// Example template: "[0.1234,-0.2381,0.5321,...]" (exactly 128 floats)

import 'dart:convert';

class FaceEnrollmentTemplateRequest {
  final String employeeId;
  final String template;       // 128-float L2-normalized MobileFaceNet embedding as JSON string
  final String modelVersion;   // Must match kFaceModelVersion = 'mobilefacenet_v1'
  final int templateVersion;   // Increment when enrollment is refreshed
  final String requestId;      // UUID v4, replay protection

  FaceEnrollmentTemplateRequest({
    required this.employeeId,
    required this.template,
    required this.modelVersion,
    required this.templateVersion,
    required this.requestId,
  });

  /// Helper to create request from List<double>
  factory FaceEnrollmentTemplateRequest.fromEmbedding({
    required String employeeId,
    required List<double> embedding,
    required String modelVersion,
    required int templateVersion,
    required String requestId,
  }) {
    return FaceEnrollmentTemplateRequest(
      employeeId: employeeId,
      template: jsonEncode(embedding),
      modelVersion: modelVersion,
      templateVersion: templateVersion,
      requestId: requestId,
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'template': template,
        'modelVersion': modelVersion,
        'templateVersion': templateVersion,
        'requestId': requestId,
      };
}
