// test/face_attendance/face_template_repository_test.dart
//
// Tests for template string conversion and mock repository logic.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_plus/app/modules/face_attendance/models/face_enrollment_template_request.dart';
import 'package:resource_plus/app/modules/face_attendance/models/face_template_response.dart';
import 'package:resource_plus/app/modules/face_attendance/repositories/face_template_repository.dart';
import 'package:resource_plus/app/modules/face_attendance/services/face_embedding_service.dart' show kEmbeddingDimension, kFaceModelVersion;

void main() {
  group('Template JSON String Conversion', () {
    test('FaceEnrollmentTemplateRequest converts embedding to JSON string', () {
      final dummyEmbedding = List.generate(kEmbeddingDimension, (i) => i * 0.01);
      
      final request = FaceEnrollmentTemplateRequest.fromEmbedding(
        employeeId: 'EMP001',
        embedding: dummyEmbedding,
        modelVersion: kFaceModelVersion,
        templateVersion: 1,
        requestId: 'req-123',
      );

      // Verify it's a valid JSON string containing exactly the floats
      expect(request.template, isA<String>());
      final decodedList = jsonDecode(request.template) as List<dynamic>;
      expect(decodedList.length, kEmbeddingDimension);
      expect((decodedList[1] as num).toDouble(), 0.01);
    });

    test('FaceTemplateResponse parses JSON string back to List<double>', () {
      final dummyEmbedding = List.generate(kEmbeddingDimension, (i) => i * 0.01);
      final jsonString = jsonEncode(dummyEmbedding);

      final response = FaceTemplateResponse(
        template: jsonString,
        modelVersion: kFaceModelVersion,
        templateVersion: 1,
      );

      final parsed = response.parseTemplate();
      expect(parsed, isA<List<double>>());
      expect(parsed.length, kEmbeddingDimension);
      expect(parsed[1], 0.01);
    });
  });

  group('MockFaceTemplateRepository', () {
    test('Should save and retrieve identical template in memory', () async {
      final repo = MockFaceTemplateRepository();
      
      // Clear static storage before test
      MockFaceTemplateRepository.clearMockStorageForTests();

      // 1. Initial get should be null
      final initialGet = await repo.getTemplate();
      expect(initialGet, isNull);

      // 2. Save template A
      final dummyEmbedding = List.generate(kEmbeddingDimension, (i) => i * 0.02);
      final request = FaceEnrollmentTemplateRequest.fromEmbedding(
        employeeId: 'EMP001',
        embedding: dummyEmbedding,
        modelVersion: kFaceModelVersion,
        templateVersion: 1,
        requestId: 'req-123',
      );

      final success = await repo.saveTemplate(request);
      expect(success, isTrue);

      // 3. Retrieve template A
      final retrieved = await repo.getTemplate();
      expect(retrieved, isNotNull);
      expect(retrieved!.modelVersion, kFaceModelVersion);
      
      final parsed = retrieved.parseTemplate();
      expect(parsed.length, kEmbeddingDimension);
      expect(parsed[1], 0.02);
    });
  });
}
