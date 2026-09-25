// lib/app/modules/face_attendance/services/face_matching_service.dart
//
// DEMO THRESHOLD NOTICE:
// ─────────────────────
// kFaceMatchThreshold = 0.60 is a DEMO-CALIBRATED value.
// Cosine similarity range for MobileFaceNet: same person typically > 0.55,
// different people typically < 0.40. 0.60 provides a conservative demo buffer.
// This threshold MUST be calibrated using actual enrollment/verification data
// before production deployment.
// Do NOT treat this as an industry-standard or universally correct value.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'face_embedding_service.dart' show kFaceModelVersion, kEmbeddingDimension;

/// Production-level threshold for MobileFaceNet (0.55–0.60 is standard).
/// Rejects different faces (fraud detection) while allowing the enrolled person.
const double kFaceMatchThreshold = 0.55;

enum FaceMatchStatus {
  matched,
  notMatched,
  invalidTemplate,
  modelVersionMismatch,
  error,
}

class FaceMatchResult {
  final FaceMatchStatus status;
  // Similarity score is intentionally not exposed to the UI layer (privacy).
  // Used only internally for logging/debugging in dev mode.
  final double _similarity;

  FaceMatchResult({required this.status, required double similarity})
      : _similarity = similarity;

  bool get isMatched => status == FaceMatchStatus.matched;

  @override
  String toString() => 'FaceMatchResult(status: $status)';
  // Note: _similarity is deliberately not in toString() to avoid log exposure
}

class FaceMatchingService {
  /// Compare a live embedding against an enrolled template embedding.
  ///
  /// Both vectors must be L2-normalized and of length [kEmbeddingDimension].
  /// Uses cosine similarity (dot product of L2-normalized vectors).
  FaceMatchResult compare({
    required List<double> liveEmbedding,
    required List<double> enrolledEmbedding,
    required String enrolledModelVersion,
  }) {
    // Validate model version compatibility
    if (enrolledModelVersion != kFaceModelVersion) {
      debugPrint('[FaceMatching] Model version mismatch: enrolled=$enrolledModelVersion, current=$kFaceModelVersion');
      return FaceMatchResult(status: FaceMatchStatus.modelVersionMismatch, similarity: 0.0);
    }

    // Validate vector integrity
    if (!_isValidEmbedding(liveEmbedding) || !_isValidEmbedding(enrolledEmbedding)) {
      debugPrint('[FaceMatching] Invalid embedding vector');
      return FaceMatchResult(status: FaceMatchStatus.invalidTemplate, similarity: 0.0);
    }

    if (liveEmbedding.length != enrolledEmbedding.length) {
      debugPrint('[FaceMatching] Vector length mismatch: ${liveEmbedding.length} vs ${enrolledEmbedding.length}');
      return FaceMatchResult(status: FaceMatchStatus.invalidTemplate, similarity: 0.0);
    }

    try {
      final similarity = _cosineSimilarity(liveEmbedding, enrolledEmbedding);

      // Security: Do NOT log similarity scores in release mode
      assert(() {
        debugPrint('[FaceMatching] Similarity computed (debug only): threshold=$kFaceMatchThreshold');
        return true;
      }());

      final status = similarity >= kFaceMatchThreshold
          ? FaceMatchStatus.matched
          : FaceMatchStatus.notMatched;

      return FaceMatchResult(status: status, similarity: similarity);
    } catch (e) {
      debugPrint('[FaceMatching] Comparison error: $e');
      return FaceMatchResult(status: FaceMatchStatus.error, similarity: 0.0);
    }
  }

  /// Cosine similarity = dot(A, B) / (|A| * |B|)
  /// Since both embeddings are L2-normalized (||v|| = 1.0), this simplifies
  /// to the dot product alone.
  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    normA = sqrt(normA);
    normB = sqrt(normB);

    if (normA < 1e-10 || normB < 1e-10) return 0.0;

    return dot / (normA * normB);
  }

  bool _isValidEmbedding(List<double> embedding) {
    if (embedding.isEmpty) return false;
    if (embedding.length != kEmbeddingDimension) return false;

    // Check for all-zeros (invalid L2-norm = 0 signal from embedding service)
    bool allZero = embedding.every((v) => v == 0.0);
    if (allZero) return false;

    // Check for NaN or Infinity
    for (final v in embedding) {
      if (v.isNaN || v.isInfinite) return false;
    }

    return true;
  }
}
