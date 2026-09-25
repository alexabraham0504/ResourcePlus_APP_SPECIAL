import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';

enum FaceQualityState {
  noFace,
  multipleFaces,
  faceTooSmall,
  faceNotCentered,
  headAngleInvalid,
  ready
}

class FaceQualityService {
  // Configurable constraints
  final double minFaceWidthRatio = 0.25; 
  final double maxHeadEulerY = 15.0; // Left/Right turn tolerance
  final double maxHeadEulerZ = 15.0; // Tilt tolerance

  FaceQualityState evaluateQuality(List<Face> faces, Size imageSize, {bool ignoreHeadAngle = false}) {
    if (faces.isEmpty) return FaceQualityState.noFace;
    if (faces.length > 1) return FaceQualityState.multipleFaces;

    final face = faces.first;

    // Check size
    final faceWidthRatio = face.boundingBox.width / imageSize.width;
    if (faceWidthRatio < minFaceWidthRatio) {
      return FaceQualityState.faceTooSmall;
    }

    // Check center alignment (roughly inside the middle 50% of the screen)
    // Relaxed to 70% if doing head-turn challenge
    final centerX = face.boundingBox.center.dx;
    final minCenter = ignoreHeadAngle ? 0.15 : 0.25;
    final maxCenter = ignoreHeadAngle ? 0.85 : 0.75;
    
    if (centerX < imageSize.width * minCenter || centerX > imageSize.width * maxCenter) {
      return FaceQualityState.faceNotCentered;
    }

    // Check rotation (looking straight ahead) - skipped if doing head-turn liveness challenge
    if (!ignoreHeadAngle && face.headEulerAngleY != null && face.headEulerAngleZ != null) {
      if (face.headEulerAngleY!.abs() > maxHeadEulerY ||
          face.headEulerAngleZ!.abs() > maxHeadEulerZ) {
        return FaceQualityState.headAngleInvalid;
      }
    }

    return FaceQualityState.ready;
  }

  String getFeedbackMessage(FaceQualityState state) {
    switch (state) {
      case FaceQualityState.noFace:
        return "Position your face inside the guide";
      case FaceQualityState.multipleFaces:
        return "Only one person should be visible";
      case FaceQualityState.faceTooSmall:
        return "Move closer";
      case FaceQualityState.faceNotCentered:
        return "Center your face in the oval";
      case FaceQualityState.headAngleInvalid:
        return "Keep your face straight";
      case FaceQualityState.ready:
        return "Hold still...";
    }
  }
}
