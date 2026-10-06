// lib/app/modules/face_attendance/controllers/face_enrollment_controller.dart
//
// DEMO ARCHITECTURE NOTICE:
// Face embedding generation and face matching are performed on-device.
// The mathematical face template is stored by the backend.
// This architecture is intended for demonstration and integration testing
// and is NOT the final production biometric security architecture.

import 'dart:math';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/face_camera_service.dart';
import '../services/face_detection_service.dart';
import '../services/face_quality_service.dart';
import '../services/attendance_security_service.dart';
import '../services/face_embedding_service.dart';
import '../services/face_preprocessing_service.dart';
import 'package:camera/camera.dart';
import '../services/face_liveness_service.dart';
import '../models/face_enrollment_template_request.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import '../repositories/face_template_repository.dart';


/// Enrollment states for clear UI feedback
enum EnrollmentState {
  idle,
  initializingCamera,
  detectingFace,
  qualityCheck,
  livenessChallenge,
  capturingSample,
  generatingEmbedding,
  processingTemplate,
  submitting,
  success,
  error,
  permissionDenied,
  modelLoadFailed,
  alreadyEnrolled,
}

class FaceEnrollmentController extends GetxController {
  final FaceCameraService cameraService = FaceCameraService();
  final FaceDetectionService detectionService = FaceDetectionService();
  final FaceQualityService qualityService = FaceQualityService();
  final FaceLivenessService livenessService = FaceLivenessService();
  final AttendanceSecurityService securityService = AttendanceSecurityService();
  final FaceEmbeddingService embeddingService = FaceEmbeddingService();
  final FacePreprocessingService preprocessingService = FacePreprocessingService();
  final FaceTemplateRepository templateRepository = ApiFaceTemplateRepository();

  final enrollmentState = EnrollmentState.idle.obs;
  final statusMessage = 'Initializing...'.obs;
  final capturedSamplesCount = 0.obs;
  final maxSamples = 3;

  final isProcessing = false.obs;

  // In-memory only — never stored in GetStorage/SharedPreferences
  final List<List<double>> _collectedEmbeddings = [];

  final _storage = GetStorage();
  Face? _lastDetectedFace;
  bool _isDetecting = false; // Prevents frame flooding and GC spikes

  @override
  void onInit() {
    super.onInit();
    _initEnrollment();
  }

  Future<void> _initEnrollment() async {
    enrollmentState.value = EnrollmentState.initializingCamera;
    statusMessage.value = 'Loading face recognition model...';

    // Add a delay to allow native CameraX and ML Kit resources from previous screens
    // (like Attendance) to be fully garbage collected by Android before re-initializing.
    await Future.delayed(const Duration(milliseconds: 800));

    // Validation: Check if already enrolled
    final isEnrolled = await templateRepository.hasTemplate();
    if (isEnrolled) {
      enrollmentState.value = EnrollmentState.alreadyEnrolled;
      statusMessage.value = 'You have already enrolled your face.';
      return;
    }

    // Load TFLite model ONCE
    final modelLoaded = await embeddingService.initialize();
    if (!modelLoaded) {
      enrollmentState.value = EnrollmentState.modelLoadFailed;
      statusMessage.value = 'Face recognition model unavailable. Please try again.';
      return;
    }

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      enrollmentState.value = EnrollmentState.permissionDenied;
      statusMessage.value = 'Camera permission is required for enrollment.';
      return;
    }

    try {
      await cameraService.initializeCamera();
      livenessService.startSession();
      enrollmentState.value = EnrollmentState.livenessChallenge;
      statusMessage.value = livenessService.getChallengeInstruction();
      cameraService.startImageStream(_processCameraFrame);
    } catch (e) {
      enrollmentState.value = EnrollmentState.error;
      statusMessage.value = 'Camera error. Please restart the screen.';
    }
  }

  void pauseCamera() {
    cameraService.stopImageStream();
  }

  void resumeCamera() {
    cameraService.startImageStream(_processCameraFrame);
  }

  Future<void> _processCameraFrame(image) async {
    if (isProcessing.value || capturedSamplesCount.value >= maxSamples || _isDetecting) return;

    _isDetecting = true;
    try {
      final faces = await detectionService.processCameraImage(image);
      if (faces == null) return; // Frame was dropped due to throttling
      
      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final qualityState = qualityService.evaluateQuality(
        faces, 
        imageSize,
        ignoreHeadAngle: !livenessService.isLive && livenessService.hasHeadTurnChallenge,
      );

      if (qualityState != FaceQualityState.ready) {
        enrollmentState.value = EnrollmentState.qualityCheck;
        statusMessage.value = qualityService.getFeedbackMessage(qualityState);
        return;
      }

      // Cache the detected face for preprocessing
      if (faces.isNotEmpty) {
        _lastDetectedFace = faces.first;
      }

      // Liveness challenge
      if (!livenessService.isLive && faces.isNotEmpty) {
        enrollmentState.value = EnrollmentState.livenessChallenge;
        final isLive = livenessService.processFrame(faces.first);
        if (!isLive) {
          statusMessage.value = livenessService.getChallengeInstruction();
          return;
        } else {
          // CRITICAL FIX: Liveness just passed (user's head is tilted).
          // Do NOT capture this frame. Return here so the next incoming frames
          // are forced to pass the quality check (which requires looking straight)
          // before capturing.
          statusMessage.value = 'Please look straight at the camera';
          return;
        }
      }

      if (livenessService.isLive && !isProcessing.value) {
        enrollmentState.value = EnrollmentState.capturingSample;
        statusMessage.value = 'Hold still...';
        await _captureSample(image);
      }
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _captureSample(dynamic cameraImage) async {
    isProcessing.value = true;

    try {
      // Do NOT stop the image stream. Stopping and starting the ImageAnalysis usecase 
      // repeatedly alongside ImageCapture causes native SIGSEGV crashes on budget Androids.
      // The `isProcessing.value = true` flag already prevents the preview frame from being processed.

      final sampleNum = capturedSamplesCount.value + 1;
      enrollmentState.value = EnrollmentState.generatingEmbedding;
      statusMessage.value = 'Generating sample $sampleNum/$maxSamples...';

      // Verify we have a valid face for cropping
      if (_lastDetectedFace == null) {
        throw Exception('No face data for preprocessing');
      }

      // We completely bypass `takePicture()` and `img.decodeImage()` which cause Native Android OOM
      // and CameraX SIGSEGV crashes. Instead, we use the `CameraImage` directly from the stream.
      
      // We need the rotation to match ML Kit's coordinate space
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final result = await preprocessingService.preprocessCameraImage(
        cameraImage,
        _lastDetectedFace!,
        frontCamera.sensorOrientation,
      );

      if (result == null) throw Exception('Preprocessing failed');
      final tensor = result['tensor'] as Float32List;

      // Generate 128-float embedding using MobileFaceNet
      final embedding = await embeddingService.generateEmbedding(tensor);
      if (embedding == null) throw Exception('Embedding generation failed');

      // Store in memory only — NOT in GetStorage
      _collectedEmbeddings.add(embedding);
      capturedSamplesCount.value++;

      if (capturedSamplesCount.value >= maxSamples) {
        // All samples collected — create final template
        // We can stop the stream now as we are done with enrollment completely
        await cameraService.stopImageStream();
        await _createAndSubmitTemplate();
      } else {
        statusMessage.value = 'Sample $sampleNum captured. Keep your face in view...';
        // Brief pause to let the user get ready for the next capture
        await Future.delayed(const Duration(milliseconds: 1000));
        // Do NOT restart the stream here. It was never stopped.
      }
    } catch (e) {
      debugPrint('[Enrollment] Sample capture failed: $e');
      enrollmentState.value = EnrollmentState.error;
      statusMessage.value = 'Error: $e';
      
      // Reset liveness and resume stream so user can retry
      await Future.delayed(const Duration(milliseconds: 3000));
      livenessService.reset();
      livenessService.startSession();
      enrollmentState.value = EnrollmentState.livenessChallenge;
      statusMessage.value = livenessService.getChallengeInstruction();
      // Do NOT call startImageStream here because it was never stopped, 
      // and calling it while it's already running causes native SIGSEGV on Android!
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> _createAndSubmitTemplate() async {
    enrollmentState.value = EnrollmentState.processingTemplate;
    statusMessage.value = 'Creating face template...';

    // Gracefully stop the camera stream now that we have all required samples.
    // This prevents a native SIGSEGV crash when the user clicks Finish and the controller is disposed.
    try {
      await cameraService.stopImageStream();
    } catch (_) {}

    try {
      if (_collectedEmbeddings.length < maxSamples) {
        throw Exception('Insufficient embeddings collected');
      }

      // Average the 3 embeddings then L2-normalize the result.
      // Averaging is appropriate for MobileFaceNet to create a robust template
      // that handles slight pose/lighting variations across samples.
      final finalTemplate = _averageAndNormalize(_collectedEmbeddings);

      await _submitTemplate(finalTemplate);
    } catch (e) {
      debugPrint('[Enrollment] Template creation failed: $e');
      enrollmentState.value = EnrollmentState.error;
      statusMessage.value = 'Enrollment failed. Please try again.';
    } finally {
      // Security: clear in-memory embeddings after processing
      _collectedEmbeddings.clear();
    }
  }

  /// Average multiple embeddings and re-normalize.
  /// Appropriate for MobileFaceNet to produce a stable enrollment template.
  List<double> _averageAndNormalize(List<List<double>> embeddings) {
    final dim = embeddings.first.length;
    final averaged = List.filled(dim, 0.0);

    for (final emb in embeddings) {
      for (int i = 0; i < dim; i++) {
        averaged[i] += emb[i] / embeddings.length;
      }
    }

    // L2-normalize the averaged vector
    double norm = 0.0;
    for (final v in averaged) {
      norm += v * v;
    }
    norm = sqrt(norm);
    if (norm < 1e-10) return averaged;

    return averaged.map((v) => v / norm).toList();
  }

  Future<void> _submitTemplate(List<double> finalTemplate) async {
    enrollmentState.value = EnrollmentState.submitting;
    statusMessage.value = 'Submitting enrollment securely...';

    try {
      // Employee identity comes from the authenticated session, NOT from UI input
      final empId = _storage.read('username') ?? '';
      if (empId.isEmpty) throw Exception('Not authenticated');

      final reqId = securityService.generateRequestId();

      final request = FaceEnrollmentTemplateRequest.fromEmbedding(
        employeeId: empId,
        embedding: finalTemplate,
        modelVersion: kFaceModelVersion,
        templateVersion: 1,
        requestId: reqId,
      );

      // DEMO: Use the repository abstraction to save the template
      final success = await templateRepository.saveTemplate(request);
      
      if (success) {
        enrollmentState.value = EnrollmentState.success;
        statusMessage.value = 'Face enrollment successful!';
      } else {
        enrollmentState.value = EnrollmentState.error;
        statusMessage.value = 'Enrollment failed. Please try again.';
      }

      /*
      // REAL API IMPLEMENTATION:
      // Later, switch `MockFaceTemplateRepository` to `ApiFaceTemplateRepository`
      // which will execute this actual POST request.
      final uri = Uri.parse(ApiEndpoints.faceEnroll);
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );
      ...
      */
    } catch (e) {
      enrollmentState.value = EnrollmentState.error;
      statusMessage.value = 'Network error during enrollment.';
      debugPrint('[Enrollment] Submit error: $e');
    }
  }

  @override
  void onClose() {
    cameraService.dispose();
    detectionService.dispose();
    embeddingService.dispose();
    // Security: ensure in-memory embeddings are cleared on close
    _collectedEmbeddings.clear();
    super.onClose();
  }
}
