// lib/app/modules/face_attendance/services/face_embedding_service.dart
//
// VERIFIED MODEL SPECIFICATION (MobileFaceNet TFLite):
// ─────────────────────────────────────────────────────
// Model file    : assets/models/mobilefacenet.tflite
// Source        : https://github.com/MCarlomagno/FaceRecognitionAuth (Apache 2.0)
// Input shape   : [1, 112, 112, 3]  (float32, RGB, normalized to [-1,+1])
// Output shape  : [1, 128]          (float32, L2-normalized embedding)
// Model version : mobilefacenet_v1
//
// DEMO ARCHITECTURE LIMITATION:
// ──────────────────────────────
// Face embedding generation runs on-device. The mathematical face template is
// stored by the backend. This design is intended for demonstration and integration
// testing and is NOT the final production biometric security architecture.
// A modified APK could potentially bypass client-side matching.
// Production requirements include server-side biometric verification.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

const String kFaceModelVersion = 'mobilefacenet_v1';
const int kEmbeddingDimension = 192;

class FaceEmbeddingService {
  static final FaceEmbeddingService _instance = FaceEmbeddingService._internal();

  factory FaceEmbeddingService() {
    return _instance;
  }

  FaceEmbeddingService._internal();
  static const String _modelAssetPath = 'assets/models/mobilefacenet.tflite';

  Interpreter? _interpreter;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize the TFLite interpreter. Call this ONCE at controller init.
  /// Do NOT call per-frame.
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        _modelAssetPath,
        options: options,
      );
      _isInitialized = true;
      debugPrint('[FaceEmbedding] MobileFaceNet interpreter loaded successfully');
      return true;
    } catch (e) {
      debugPrint('[FaceEmbedding] Failed to load interpreter: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Generate a 192-dimensional face embedding from a preprocessed tensor.
  ///
  /// [preprocessedTensor] must be a Float32List of length 1*112*112*3
  /// produced by FacePreprocessingService.
  ///
  /// Returns a L2-normalized List<double> of length 192, or null on failure.
  /// Does NOT store the result permanently. Caller must handle memory.
  Future<List<double>?> generateEmbedding(Float32List preprocessedTensor) async {
    if (!_isInitialized || _interpreter == null) {
      debugPrint('[FaceEmbedding] Interpreter not initialized');
      return null;
    }

    try {
      // Input tensor: shape [1, 112, 112, 3]
      final inputShape = [1, 112, 112, 3];
      final inputBuffer = preprocessedTensor.reshape(inputShape);

      // Output tensor: shape [1, 128]
      final outputBuffer = List.generate(
        1,
        (_) => List.filled(kEmbeddingDimension, 0.0),
      );

      _interpreter!.run(inputBuffer, outputBuffer);

      // Extract the 128-float embedding from output
      final rawEmbedding = outputBuffer[0].cast<double>();

      // L2-normalize the embedding vector for consistent cosine similarity
      // (MobileFaceNet outputs are approximately normalized but we normalize
      // explicitly to guarantee unit vector for cosine similarity)
      final normalized = _l2Normalize(rawEmbedding);

      // Security: Do NOT log the embedding vector
      debugPrint('[FaceEmbedding] Embedding generated successfully (${normalized.length} dims)');

      return normalized;
    } catch (e) {
      debugPrint('[FaceEmbedding] Inference error: $e');
      return null;
    }
  }

  /// L2-normalize a vector so that ||v|| = 1.0
  /// Required for consistent cosine similarity computation.
  List<double> _l2Normalize(List<double> vector) {
    double norm = 0.0;
    for (final v in vector) {
      norm += v * v;
    }
    norm = sqrt(norm);

    if (norm < 1e-10) {
      // Avoid division by zero — return zero vector as invalid signal
      return List.filled(vector.length, 0.0);
    }

    return vector.map((v) => v / norm).toList();
  }

  void dispose() {
    // Singleton: Do not close the TFLite interpreter to prevent native reallocation crashes
  }
}
