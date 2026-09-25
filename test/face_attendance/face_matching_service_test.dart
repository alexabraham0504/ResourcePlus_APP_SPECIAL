// test/face_attendance/face_matching_service_test.dart
//
// Unit tests for FaceMatchingService.
// These tests are deterministic mathematical tests, separate from device inference.
// They test the comparison logic independently of the TFLite model.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_plus/app/modules/face_attendance/services/face_matching_service.dart';
import 'package:resource_plus/app/modules/face_attendance/services/face_embedding_service.dart'
    show kFaceModelVersion, kEmbeddingDimension;

void main() {
  late FaceMatchingService matchingService;

  setUp(() {
    matchingService = FaceMatchingService();
  });

  // Helper: Create a L2-normalized unit vector of given dimension
  List<double> makeUnitVector(int dim, {double value = 1.0}) {
    final v = List.filled(dim, value / dim);
    double norm = sqrt(v.fold(0.0, (sum, x) => sum + x * x));
    return v.map((x) => x / norm).toList();
  }

  // Helper: Create an L2-normalized vector pointing in a different direction
  List<double> makeOrthogonalVector(int dim) {
    final v = List<double>.generate(dim, (i) => i % 2 == 0 ? 1.0 : -1.0);
    double norm = sqrt(v.fold(0.0, (sum, x) => sum + x * x));
    return v.map((x) => x / norm).toList();
  }

  group('FaceMatchingService - Same Person (MATCH)', () {
    test('Identical embeddings should return MATCHED', () {
      final embedding = makeUnitVector(kEmbeddingDimension);
      final result = matchingService.compare(
        liveEmbedding: embedding,
        enrolledEmbedding: List.from(embedding),
        enrolledModelVersion: kFaceModelVersion,
      );
      expect(result.status, FaceMatchStatus.matched);
    });

    test('Very similar embeddings (small perturbation) should return MATCHED', () {
      final base = makeUnitVector(kEmbeddingDimension);
      final perturbed = List<double>.from(base);
      // Small perturbation
      final rng = Random(42);
      for (int i = 0; i < kEmbeddingDimension; i++) {
        perturbed[i] += (rng.nextDouble() - 0.5) * 0.05;
      }
      // Re-normalize
      double norm = sqrt(perturbed.fold(0.0, (s, v) => s + v * v));
      final normalizedPerturbed = perturbed.map((v) => v / norm).toList();

      final result = matchingService.compare(
        liveEmbedding: normalizedPerturbed,
        enrolledEmbedding: base,
        enrolledModelVersion: kFaceModelVersion,
      );
      expect(result.status, FaceMatchStatus.matched);
    });
  });

  group('FaceMatchingService - Different Person (NO MATCH)', () {
    test('Opposite direction embeddings should return NOT_MATCHED', () {
      final embedding = makeUnitVector(kEmbeddingDimension, value: 1.0);
      final opposite = embedding.map((v) => -v).toList();
      final result = matchingService.compare(
        liveEmbedding: embedding,
        enrolledEmbedding: opposite,
        enrolledModelVersion: kFaceModelVersion,
      );
      expect(result.status, FaceMatchStatus.notMatched);
    });

    test('Orthogonal embeddings should return NOT_MATCHED (similarity ≈ 0)', () {
      final a = makeUnitVector(kEmbeddingDimension);
      final b = makeOrthogonalVector(kEmbeddingDimension);
      final result = matchingService.compare(
        liveEmbedding: a,
        enrolledEmbedding: b,
        enrolledModelVersion: kFaceModelVersion,
      );
      expect(result.status, FaceMatchStatus.notMatched);
    });
  });

  group('FaceMatchingService - Invalid Inputs', () {
    test('Empty live embedding should return INVALID_TEMPLATE', () {
      final enrolled = makeUnitVector(kEmbeddingDimension);
      final result = matchingService.compare(
        liveEmbedding: [],
        enrolledEmbedding: enrolled,
        enrolledModelVersion: kFaceModelVersion,
      );
      expect(result.status, FaceMatchStatus.invalidTemplate);
    });

    test('All-zero embedding should return INVALID_TEMPLATE', () {
      final zeros = List.filled(kEmbeddingDimension, 0.0);
      final enrolled = makeUnitVector(kEmbeddingDimension);
      final result = matchingService.compare(
        liveEmbedding: zeros,
        enrolledEmbedding: enrolled,
        enrolledModelVersion: kFaceModelVersion,
      );
      expect(result.status, FaceMatchStatus.invalidTemplate);
    });

    test('NaN in embedding should return INVALID_TEMPLATE', () {
      final nanEmbedding = makeUnitVector(kEmbeddingDimension);
      nanEmbedding[0] = double.nan;
      final enrolled = makeUnitVector(kEmbeddingDimension);
      final result = matchingService.compare(
        liveEmbedding: nanEmbedding,
        enrolledEmbedding: enrolled,
        enrolledModelVersion: kFaceModelVersion,
      );
      expect(result.status, FaceMatchStatus.invalidTemplate);
    });

    test('Infinity in embedding should return INVALID_TEMPLATE', () {
      final infEmbedding = makeUnitVector(kEmbeddingDimension);
      infEmbedding[5] = double.infinity;
      final enrolled = makeUnitVector(kEmbeddingDimension);
      final result = matchingService.compare(
        liveEmbedding: infEmbedding,
        enrolledEmbedding: enrolled,
        enrolledModelVersion: kFaceModelVersion,
      );
      expect(result.status, FaceMatchStatus.invalidTemplate);
    });

    test('Wrong vector length should return INVALID_TEMPLATE', () {
      final shortEmbedding = makeUnitVector(64); // wrong dimension
      final enrolled = makeUnitVector(kEmbeddingDimension);
      final result = matchingService.compare(
        liveEmbedding: shortEmbedding,
        enrolledEmbedding: enrolled,
        enrolledModelVersion: kFaceModelVersion,
      );
      expect(result.status, FaceMatchStatus.invalidTemplate);
    });
  });

  group('FaceMatchingService - Model Version', () {
    test('Model version mismatch should return MODEL_VERSION_MISMATCH', () {
      final live = makeUnitVector(kEmbeddingDimension);
      final enrolled = makeUnitVector(kEmbeddingDimension);
      final result = matchingService.compare(
        liveEmbedding: live,
        enrolledEmbedding: enrolled,
        enrolledModelVersion: 'mobilefacenet_v0', // Old version
      );
      expect(result.status, FaceMatchStatus.modelVersionMismatch);
    });

    test('Correct model version should not trigger mismatch', () {
      final live = makeUnitVector(kEmbeddingDimension);
      final enrolled = List<double>.from(live);
      final result = matchingService.compare(
        liveEmbedding: live,
        enrolledEmbedding: enrolled,
        enrolledModelVersion: kFaceModelVersion,
      );
      expect(result.status, isNot(FaceMatchStatus.modelVersionMismatch));
    });
  });
}
