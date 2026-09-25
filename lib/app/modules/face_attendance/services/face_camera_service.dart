import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FaceCameraService {
  CameraController? _cameraController;
  static Future<void>? _globalDisposeFuture;

  CameraController? get controller => _cameraController;

  bool get isInitialized => _cameraController?.value.isInitialized ?? false;

  Future<void> initializeCamera() async {
    try {
      // Wait for any pending disposal across ALL instances to finish before re-initializing
      if (_globalDisposeFuture != null) {
        await _globalDisposeFuture;
        _globalDisposeFuture = null;
      }

      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }

      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      rethrow;
    }
  }

  bool _isProcessingFrame = false;

  void startImageStream(void Function(CameraImage image) onImage) {
    if (isInitialized && !_cameraController!.value.isStreamingImages) {
      _cameraController!.startImageStream((image) {
        if (_isProcessingFrame) return; // Drop frame to prevent native OOM queueing
        _isProcessingFrame = true;
        try {
          onImage(image);
        } finally {
          _isProcessingFrame = false;
        }
      });
    }
  }

  Future<void> stopImageStream() async {
    if (isInitialized && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }
    _isProcessingFrame = false; // Reset lock
  }

  Future<XFile?> takePicture() async {
    if (isInitialized && !_cameraController!.value.isTakingPicture) {
      return await _cameraController!.takePicture();
    }
    return null;
  }

  Future<void> dispose() async {
    if (_cameraController != null) {
      final c = _cameraController!;
      _cameraController = null;
      
      try {
        if (c.value.isStreamingImages) {
          await c.stopImageStream();
        }
      } catch (_) {}
      
      try {
        _globalDisposeFuture = c.dispose();
        await _globalDisposeFuture;
      } catch (_) {}
    }
  }
}
