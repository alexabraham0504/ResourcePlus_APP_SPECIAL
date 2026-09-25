// lib/app/modules/face_attendance/models/face_template_response.dart
//
// Response model from backend when retrieving enrolled face template.
// The backend returns the template as a JSON string for now.
// Example template: "[0.1234,-0.2381,0.5321,...]" (exactly 128 floats)

import 'dart:convert';

class FaceTemplateResponse {
  final String template;         // JSON string of 128 floats
  final String modelVersion;     // e.g. 'mobilefacenet_v1'
  final int templateVersion;

  FaceTemplateResponse({
    required this.template,
    required this.modelVersion,
    required this.templateVersion,
  });

  factory FaceTemplateResponse.fromJson(Map<String, dynamic> json) {
    return FaceTemplateResponse(
      template: json['template'] as String,
      modelVersion: json['modelVersion'] as String,
      templateVersion: json['templateVersion'] as int,
    );
  }

  /// Helper to convert the JSON string back into a List of doubles
  List<double> parseTemplate() {
    final List<dynamic> decoded = jsonDecode(template);
    return decoded.map((v) => (v as num).toDouble()).toList();
  }
}
