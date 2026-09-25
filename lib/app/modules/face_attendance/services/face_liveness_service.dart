import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessChallenge {
  turnHead
}

class FaceLivenessService {
  String? _currentSessionId;
  LivenessChallenge? _currentChallenge;
  bool _challengeCompleted = false;

  void startSession() {
    _currentSessionId = 'LIVENESS_${DateTime.now().millisecondsSinceEpoch}';
    _challengeCompleted = false;
    
    // Pick a random challenge
    final random = Random();
    _currentChallenge = LivenessChallenge.values[random.nextInt(LivenessChallenge.values.length)];
  }

  bool processFrame(Face face) {
    if (_challengeCompleted) return true;
    if (_currentChallenge == null) return false;

    switch (_currentChallenge!) {
      case LivenessChallenge.turnHead:
        // Absolute angle > 15 proves 3D head movement regardless of camera mirroring
        if ((face.headEulerAngleY ?? 0).abs() > 15) _challengeCompleted = true;
        break;
    }

    return _challengeCompleted;
  }

  String getChallengeInstruction() {
    if (_challengeCompleted) return "Challenge Complete!";
    switch (_currentChallenge) {
      case LivenessChallenge.turnHead: return "Turn your head slightly";
      default: return "";
    }
  }

  bool get isLive => _challengeCompleted;
  
  bool get hasHeadTurnChallenge {
    if (_challengeCompleted) return false;
    return _currentChallenge == LivenessChallenge.turnHead;
  }
  
  String getSessionEvidence() {
    return '$_currentSessionId|Challenge: ${_currentChallenge?.name}|Completed: $_challengeCompleted';
  }

  void reset() {
    _currentSessionId = null;
    _currentChallenge = null;
    _challengeCompleted = false;
  }
}
