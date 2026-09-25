import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionService {
  static final FaceDetectionService _instance = FaceDetectionService._internal();
  
  factory FaceDetectionService() {
    return _instance;
  }
  
  FaceDetectionService._internal();
  late final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.25,
    ),
  );

  bool _isProcessing = false;
  int _lastProcessTime = 0;
  bool isPaused = false;

  void pause() => isPaused = true;
  void resume() => isPaused = false;

  /// Processes a camera frame and returns a list of faces.
  /// Skips processing if a frame is already being processed or if less than 250ms have passed.
  Future<List<Face>?> processCameraImage(CameraImage image) async {
    if (isPaused) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Increased throttle to 800ms to reduce simultaneous RAM pressure on low-end devices
    if (_isProcessing || (now - _lastProcessTime) < 800) return null;
    
    _isProcessing = true;
    _lastProcessTime = now;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: Platform.isAndroid
              ? InputImageFormat.nv21
              : InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      debugPrint('Face detection error: $e');
      return [];
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    // Singleton: Do not close the FaceDetector to prevent native reallocation crashes
  }
}
