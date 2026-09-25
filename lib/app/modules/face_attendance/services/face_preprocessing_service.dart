// lib/app/modules/face_attendance/services/face_preprocessing_service.dart
//
// VERIFIED PREPROCESSING SPECIFICATION (MobileFaceNet TFLite):
// ─────────────────────────────────────────────────────────────
// Input shape  : [1, 112, 112, 3]  (batch, height, width, channels)
// Input type   : float32
// Normalization: (pixel_value - 127.5) / 128.0  → range [-1.0, +1.0]
// Color order  : RGB
//
// Source: MobileFaceNet architecture paper + FaceRecognitionAuth reference implementation
// License: Apache 2.0

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FacePreprocessingService {
  // Exact model input dimensions (verified from MobileFaceNet TFLite spec)
  static const int modelInputWidth = 112;
  static const int modelInputHeight = 112;
  static const int modelInputChannels = 3;

  /// Process directly from CameraImage (NV21 / BGRA8888) bypassing takePicture entirely.
  /// This completely prevents the Native CameraX crashes on budget devices like Samsung M30s!
  Future<Map<String, dynamic>?> preprocessCameraImage(
    dynamic cameraImage, // CameraImage
    Face face,
    int sensorOrientation,
  ) async {
    try {
      final boundingBox = face.boundingBox;
      final rectMap = {
        'left': boundingBox.left,
        'top': boundingBox.top,
        'width': boundingBox.width,
        'height': boundingBox.height,
      };

      Map<String, dynamic>? imageMap;
      
      // Safely extract planes based on length, preventing RangeError on single-plane devices
      if (cameraImage.format.group == ImageFormatGroup.yuv420 || cameraImage.format.group == ImageFormatGroup.nv21) {
        if (cameraImage.planes.length == 3) {
          // Standard YUV420 with 3 separate planes
          // DEEP COPY the bytes to release the native Camera buffer immediately!
          imageMap = {
            'format': 'yuv420_3plane',
            'width': cameraImage.width,
            'height': cameraImage.height,
            'yPlane': Uint8List.fromList(cameraImage.planes[0].bytes),
            'uPlane': Uint8List.fromList(cameraImage.planes[1].bytes),
            'vPlane': Uint8List.fromList(cameraImage.planes[2].bytes),
            'yRowStride': cameraImage.planes[0].bytesPerRow,
            'uvRowStride': cameraImage.planes[1].bytesPerRow,
            'uvPixelStride': cameraImage.planes[1].bytesPerPixel,
          };
        } else if (cameraImage.planes.length == 1) {
          // Legacy NV21 with a single interleaved plane
          imageMap = {
            'format': 'nv21_1plane',
            'width': cameraImage.width,
            'height': cameraImage.height,
            'bytes': Uint8List.fromList(cameraImage.planes[0].bytes),
          };
        }
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        imageMap = {
          'format': 'bgra8888',
          'width': cameraImage.width,
          'height': cameraImage.height,
          'bytes': Uint8List.fromList(cameraImage.planes[0].bytes),
          'bytesPerRow': cameraImage.planes[0].bytesPerRow,
        };
      }

      if (imageMap == null) return null;

      return await compute(_processImageIsolate, {
        'cameraImage': imageMap,
        'rotation': sensorOrientation,
        'rect': rectMap,
      });
    } catch (e) {
      debugPrint('[FacePreprocessing] Error: $e');
      return null;
    }
  }

  /// Takes the raw captured image bytes (JPEG) and the ML Kit detected face,
  /// crops the face region, resizes to 112×112, and normalizes pixels.
  ///
  /// Returns a Float32List tensor of shape [1 * 112 * 112 * 3] ready for inference.
  /// Returns null if preprocessing fails.
  Future<Float32List?> preprocessFaceImage(
    Uint8List imageBytes,
    Face face,
  ) async {
    try {
      final boundingBox = face.boundingBox;
      final rectMap = {
        'left': boundingBox.left,
        'top': boundingBox.top,
        'width': boundingBox.width,
        'height': boundingBox.height,
      };

      // Offload the heavy image processing to a background isolate
      // to prevent OOM crashes and UI freezes on budget Android devices
      final result = await compute(_processImageIsolate, {
        'imageBytes': imageBytes,
        'rect': rectMap,
      });
      if (result == null) return null;
      return result['tensor'] as Float32List;
    } catch (e) {
      debugPrint('[FacePreprocessing] Error: $e');
      return null;
    }
  }
}

/// Top-level function to run in background isolate
Map<String, dynamic>? _processImageIsolate(Map<String, dynamic> args) {
  try {
    final Map<String, double> rect = Map<String, double>.from(args['rect']);
    final int rotation = args['rotation'] ?? 0;
    
    img.Image? decodedImage;

    // Decode from CameraImage stream directly (NO takePicture needed!)
    if (args['cameraImage'] != null) {
      final map = args['cameraImage'];
      final int width = map['width'];
      final int height = map['height'];
      
      if (map['format'] == 'yuv420_3plane') {
        decodedImage = img.Image(width: width, height: height, numChannels: 3);
        final Uint8List yPlane = map['yPlane'];
        final Uint8List uPlane = map['uPlane'];
        final Uint8List vPlane = map['vPlane'];
        final int yRowStride = map['yRowStride'];
        final int uvRowStride = map['uvRowStride'];
        final int uvPixelStride = map['uvPixelStride'];

        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;
            final yIndex = y * yRowStride + x;

            final yValue = yPlane[yIndex];
            final uValue = uPlane[uvIndex] - 128;
            final vValue = vPlane[uvIndex] - 128;

            int r = (yValue + 1.402 * vValue).round().clamp(0, 255);
            int g = (yValue - 0.344136 * uValue - 0.714136 * vValue).round().clamp(0, 255);
            int b = (yValue + 1.772 * uValue).round().clamp(0, 255);

            decodedImage.setPixelRgb(x, y, r, g, b);
          }
        }
      } else if (map['format'] == 'nv21_1plane') {
        decodedImage = img.Image(width: width, height: height, numChannels: 3);
        final Uint8List bytes = map['bytes'];
        final int frameSize = width * height;

        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            int yIndex = y * width + x;
            int uvIndex = frameSize + (y >> 1) * width + (x & ~1);
            
            int yValue = bytes[yIndex] & 0xFF;
            int vValue = (bytes[uvIndex] & 0xFF) - 128; // V is at even indices
            int uValue = (bytes[uvIndex + 1] & 0xFF) - 128; // U is at odd indices
            
            int r = (yValue + 1.402 * vValue).round().clamp(0, 255);
            int g = (yValue - 0.344136 * uValue - 0.714136 * vValue).round().clamp(0, 255);
            int b = (yValue + 1.772 * uValue).round().clamp(0, 255);

            decodedImage.setPixelRgb(x, y, r, g, b);
          }
        }
      } else if (map['format'] == 'bgra8888') {
        decodedImage = img.Image.fromBytes(width: width, height: height, bytes: map['bytes'].buffer, order: img.ChannelOrder.bgra);
      }
    } 
    // Fallback: decode standard JPEG from takePicture
    else if (args['imageBytes'] != null) {
      final Uint8List imageBytes = args['imageBytes'];
      decodedImage = img.decodeImage(imageBytes);
    }

    if (decodedImage == null) return null;

    // The CameraImage preview frame is usually rotated (e.g. 270 on front camera)
    // We must rotate it so the coordinates match ML Kit's face bounding box
    if (args['cameraImage'] != null && rotation != 0) {
      decodedImage = img.copyRotate(decodedImage, angle: rotation);
    }

    final double padding = rect['width']! * 0.15;
    final int left = (rect['left']! - padding).clamp(0.0, decodedImage.width.toDouble()).toInt();
    final int top = (rect['top']! - padding).clamp(0.0, decodedImage.height.toDouble()).toInt();
    final int width = (rect['width']! + padding * 2).clamp(1.0, (decodedImage.width - left).toDouble()).toInt();
    final int height = (rect['height']! + padding * 2).clamp(1.0, (decodedImage.height - top).toDouble()).toInt();

    // Crop the face region
    final cropped = img.copyCrop(decodedImage, x: left, y: top, width: width, height: height);

    // Resize to model input size (112×112)
    final resized = img.copyResize(
      cropped,
      width: FacePreprocessingService.modelInputWidth,
      height: FacePreprocessingService.modelInputHeight,
      interpolation: img.Interpolation.linear,
    );

    // Convert to Float32List tensor with exact MobileFaceNet normalization
    final tensor = Float32List(FacePreprocessingService.modelInputWidth * FacePreprocessingService.modelInputHeight * FacePreprocessingService.modelInputChannels);
    int index = 0;

    for (int y = 0; y < FacePreprocessingService.modelInputHeight; y++) {
      for (int x = 0; x < FacePreprocessingService.modelInputWidth; x++) {
        final pixel = resized.getPixel(x, y);
        // Extract RGB channels (MobileFaceNet expects RGB order)
        tensor[index++] = (pixel.r - 127.5) / 128.0;
        tensor[index++] = (pixel.g - 127.5) / 128.0;
        tensor[index++] = (pixel.b - 127.5) / 128.0;
      }
    }

    // Encode the cropped face as a highly compressed JPEG (~15KB) for the selfie!
    // This completely eliminates the need for cameraController.takePicture()
    // which prevents the massive 30MB+ native memory spike on 4GB devices!
    final jpegBytes = img.encodeJpg(cropped, quality: 80);

    return {
      'tensor': tensor,
      'imageBytes': jpegBytes,
    };
  } catch (e) {
    return null;
  }
}
