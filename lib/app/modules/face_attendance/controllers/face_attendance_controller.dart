// lib/app/modules/face_attendance/controllers/face_attendance_controller.dart
//
// VERIFICATION FLOW:
// IDLE → INITIALIZING_CAMERA → DETECTING_FACE → CHECKING_QUALITY →
// LIVENESS_CHALLENGE → CAPTURING → GENERATING_EMBEDDING →
// LOADING_ENROLLED_TEMPLATE → COMPARING_FACE →
// FACE_MATCHED / FACE_NOT_MATCHED / NO_ENROLLMENT → PUNCHING → SUCCESS / ERROR
//
// PUNCH IS BLOCKED UNLESS ALL OF THESE PASS:
//   ✅ Liveness challenge completed
//   ✅ Embedding generated successfully
//   ✅ Enrolled template retrieved from backend
//   ✅ Cosine similarity ≥ kFaceMatchThreshold (0.60)
//
// DEMO ARCHITECTURE NOTICE:
// On-device face matching is for demonstration only. A modified APK could
// bypass client-side matching. Production requires server-side biometric
// verification, certified PAD, and device integrity checks.

import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/face_camera_service.dart';
import '../services/face_detection_service.dart';
import '../services/face_quality_service.dart';
import '../services/face_liveness_service.dart';
import '../services/attendance_security_service.dart';
import '../services/face_embedding_service.dart';
import '../services/face_preprocessing_service.dart';
import '../services/face_matching_service.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../repositories/face_template_repository.dart';
import '../../home/controllers/home_controller.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'package:http_parser/http_parser.dart';
import '../../../config/api_endpoints.dart';
import '../../home/controllers/hr_portal_controller.dart';
import '../../../controllers/language_controller.dart';
import 'package:geolocator/geolocator.dart';
import '../../../routes/app_routes.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

/// All possible states in the verification flow
enum VerificationState {
  idle,
  initializingCamera,
  detectingFace,
  checkingQuality,
  livenessChallenge,
  capturing,
  generatingEmbedding,
  loadingEnrolledTemplate,
  comparingFace,
  faceMatched,
  faceNotMatched,
  noEnrollment,
  punching,
  success,
  error,
  permissionDenied,
  modelLoadFailed,
  alreadySubmitted,
}

class FaceAttendanceController extends GetxController {
  final FaceCameraService cameraService = FaceCameraService();
  final FaceDetectionService detectionService = FaceDetectionService();
  final FaceQualityService qualityService = FaceQualityService();
  final FaceLivenessService livenessService = FaceLivenessService();
  final AttendanceSecurityService securityService = AttendanceSecurityService();
  final FaceEmbeddingService embeddingService = FaceEmbeddingService();
  final FacePreprocessingService preprocessingService = FacePreprocessingService();
  final FaceMatchingService matchingService = FaceMatchingService();
  final FaceTemplateRepository templateRepository = ApiFaceTemplateRepository();

  final verificationState = VerificationState.idle.obs;
  final statusMessage = 'initializing'.tr.obs;
  final isProcessing = false.obs;
  final isPunchEnabled = false.obs; // Only true after full verification pipeline

  // checkType: 'I' for IN, 'O' for OUT
  final checkType = 'I'.obs;

  // Live Overlay Data
  final currentTime = ''.obs;
  final currentDate = ''.obs;
  final mockShift = 'Morning Shift (09:00 - 18:00)'.obs;
  final mockLocation = 'fetching_location'.tr.obs;
  Timer? _clockTimer;

  final _storage = GetStorage();
  Face? _lastDetectedFace;
  bool _hasSubmitted = false; // Duplicate submission prevention
  bool _isDetecting = false; // Prevents frame flooding and GC spikes

  // In-memory only — enrollment template retrieved from backend
  List<double>? _enrolledTemplate;
  String? _enrolledModelVersion;

  String _cachedLocationMeta = '0.000000|0.000000| Address : 0/0,';

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments is String) {
      checkType.value = Get.arguments as String;
    }
    // Stop BLE scan while camera + TFLite are active to free native heap
    try { FlutterBackgroundService().invoke('pauseScan'); } catch (_) {}
    detectionService.resume(); // Ensure singleton is unpaused
    _startClock();
    // Delay init so the route transition completes before native libs load
    Future.delayed(const Duration(milliseconds: 500), _initAttendance);
  }

  Future<void> _fetchLiveLocation() async {
    try {
      final locMeta = await securityService.buildLocationMetadata();
      _cachedLocationMeta = locMeta;
      // Format: "lat|lng| Address : ..."
      final parts = locMeta.split('|');
      if (parts.length >= 3) {
        final addressPart = parts[2].replaceAll('Address :', '').trim();
        if (addressPart.toLowerCase().contains('disabled') || addressPart.toLowerCase().contains('error')) {
           mockLocation.value = 'unknown_location'.tr;
        } else {
           mockLocation.value = addressPart;
        }
      } else {
        mockLocation.value = 'unknown_location'.tr;
      }
    } catch (e) {
      mockLocation.value = 'unknown_location'.tr;
    }
  }

  void _startClock() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    final now = DateTime.now();
    currentTime.value = DateFormat('hh:mm:ss a').format(now);
    currentDate.value = DateFormat('EEE, MMM dd, yyyy').format(now);
  }

  Future<void> _initAttendance() async {
    verificationState.value = VerificationState.initializingCamera;
    statusMessage.value = 'loading_models_verifying'.tr;

    // Add a delay to allow native CameraX and ML Kit resources from previous screens
    // (like Enrollment) to be fully garbage collected by Android before re-initializing.
    await Future.delayed(const Duration(milliseconds: 800));

    // Load TFLite model ONCE at startup
    final modelLoaded = await embeddingService.initialize();
    if (!modelLoaded) {
      verificationState.value = VerificationState.modelLoadFailed;
      statusMessage.value = 'face_model_unavailable'.tr;
      return;
    }

    // Strict Location Check
    final locStatus = await Permission.locationWhenInUse.request();
    if (!locStatus.isGranted) {
      verificationState.value = VerificationState.permissionDenied;
      statusMessage.value = 'location_permission_required'.tr;
      return;
    }

    final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationEnabled) {
      verificationState.value = VerificationState.permissionDenied;
      statusMessage.value = 'turn_on_gps'.tr;
      return;
    }

    // Re-fetch location after confirming it is enabled
    await _fetchLiveLocation();

    // Camera Check
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      verificationState.value = VerificationState.permissionDenied;
      statusMessage.value = 'camera_permission_denied'.tr;
      return;
    }

    try {
      await cameraService.initializeCamera();
      livenessService.startSession();
      verificationState.value = VerificationState.livenessChallenge;
      statusMessage.value = livenessService.getChallengeInstruction();
      cameraService.startImageStream(_processCameraFrame);
    } catch (e) {
      verificationState.value = VerificationState.error;
      statusMessage.value = 'camera_error_restart'.tr;
    }
  }

  Future<void> restartScanner() async {
    isProcessing.value = false;
    isPunchEnabled.value = false;
    verificationState.value = VerificationState.initializingCamera;
    statusMessage.value = 'reinitializing_camera'.tr;
    try {
      await cameraService.initializeCamera();
      livenessService.reset();
      livenessService.startSession();
      verificationState.value = VerificationState.livenessChallenge;
      statusMessage.value = livenessService.getChallengeInstruction();
      cameraService.startImageStream(_processCameraFrame);
    } catch (e) {
      verificationState.value = VerificationState.error;
      statusMessage.value = 'failed_to_restart_camera'.tr;
    }
  }

  void pauseCamera() {
    cameraService.stopImageStream();
  }

  void resumeCamera() {
    cameraService.startImageStream(_processCameraFrame);
  }

  Future<void> _processCameraFrame(image) async {
    // After liveness is complete we stop processing live frames
    if (isProcessing.value || isPunchEnabled.value || _isDetecting) return;
    
    _isDetecting = true;
    try {
      final faces = await detectionService.processCameraImage(image);
      if (faces == null) return; // Frame was dropped due to throttling

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

      // Step 1: Quality check
      final qualityState = qualityService.evaluateQuality(
        faces, 
        imageSize,
        ignoreHeadAngle: !livenessService.isLive && livenessService.hasHeadTurnChallenge,
      );
      if (qualityState != FaceQualityState.ready) {
        verificationState.value = VerificationState.checkingQuality;
        statusMessage.value = qualityService.getFeedbackMessage(qualityState);
        return;
      }

      // Cache face for preprocessing
      if (faces.isNotEmpty) {
        _lastDetectedFace = faces.first;
      }

      // Step 2: Liveness challenge
      if (!livenessService.isLive && faces.isNotEmpty) {
        verificationState.value = VerificationState.livenessChallenge;
        final isLive = livenessService.processFrame(faces.first);
        if (!isLive) {
          statusMessage.value = livenessService.getChallengeInstruction();
          return;
        } else {
          // CRITICAL FIX: Liveness just passed (user's head is tilted).
          // Do NOT capture this frame. Return here so the next incoming frames
          // are forced to pass the quality check (which requires looking straight)
          // before reaching the capture phase.
          statusMessage.value = 'Please look straight at the camera';
          return;
        }
      }

      // Liveness passed — proceed to full verification pipeline
      if (livenessService.isLive && !isProcessing.value) {
        // CRITICAL FIX: Do NOT stop native image stream, as CameraX crashes if takePicture
        // is called immediately after stopping ImageAnalysis.
        // Instead, pause Dart ML Kit processing to prevent memory crashes!
        detectionService.pause();
        await _runFullVerificationPipeline(image);
      }
    } finally {
      _isDetecting = false;
    }
  }

  /// Full pipeline: Capture → Embedding → Fetch Template → Compare
  /// PUNCH is only enabled if all steps pass.
  Future<void> _runFullVerificationPipeline(dynamic cameraImage) async {
    isProcessing.value = true;
    
    try {
      verificationState.value = VerificationState.capturing;
      statusMessage.value = 'capturing'.tr;

      if (_lastDetectedFace == null) throw Exception('No face data available');

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

      final liveEmbedding = await embeddingService.generateEmbedding(tensor);
      if (liveEmbedding == null) throw Exception('Embedding generation failed');

      // CAPTURE THE PICTURE NATIVELY (ZERO MEMORY LEAK)
      // We skip takePicture() entirely because it causes a massive 30MB+ native memory 
      // spike that triggers the Samsung Low Memory Killer (LMK).
      // Instead, we reuse the highly compressed JPEG (15KB) that was just generated 
      // by the Preprocessing Isolate!
      _pendingImageBytes = result['imageBytes'] as List<int>;

      // Step 5: Fetch enrolled template from backend
      verificationState.value = VerificationState.loadingEnrolledTemplate;
      statusMessage.value = 'loading_enrolled_face'.tr;

      final templateFetched = await _fetchEnrolledTemplate();
      if (!templateFetched) {
        // noEnrollment state already set inside _fetchEnrolledTemplate
        return;
      }

      // Step 6: Compare embeddings
      verificationState.value = VerificationState.comparingFace;
      statusMessage.value = 'comparing_face'.tr;

      final matchResult = matchingService.compare(
        liveEmbedding: liveEmbedding,
        enrolledEmbedding: _enrolledTemplate!,
        enrolledModelVersion: _enrolledModelVersion!,
      );

      if (matchResult.isMatched) {
        await _autoDetermineCheckType();

        verificationState.value = VerificationState.faceMatched;
        statusMessage.value = 'face_matched_ready'.tr;
        isPunchEnabled.value = true;

        // Selfie is already cached as _pendingImageBytes during capture
      } else {
        verificationState.value = VerificationState.faceNotMatched;
        statusMessage.value = 'face_verification_failed'.tr;
        // Reset liveness so user must redo the challenge
        await Future.delayed(const Duration(seconds: 2));
        _retryVerification();
      }
    } catch (e) {
      debugPrint('[FaceAttendance] Pipeline error: $e');
      verificationState.value = VerificationState.error;
      statusMessage.value = '${"error".tr}: $e';
      await Future.delayed(const Duration(seconds: 3));
      _retryVerification();
    } finally {
      // Security: clear live embedding (was in local scope, GC handles it)
      isProcessing.value = false;
    }
  }

  List<int>? _pendingImageBytes;

  Future<bool> _fetchEnrolledTemplate() async {
    try {
      // DEMO: Use the repository abstraction to get the template
      final templateResponse = await templateRepository.getTemplate();
      
      if (templateResponse == null) {
        verificationState.value = VerificationState.noEnrollment;
        statusMessage.value = 'no_face_enrolled'.tr;
        return false;
      }

      // Parse the JSON string back to a List<double>
      _enrolledTemplate = templateResponse.parseTemplate();
      _enrolledModelVersion = templateResponse.modelVersion;
      return true;

      /*
      // REAL API IMPLEMENTATION:
      // Later, switch `MockFaceTemplateRepository` to `ApiFaceTemplateRepository`
      // which will execute this actual GET request.
      final uri = Uri.parse(ApiEndpoints.faceGetTemplate);
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 404) {
        verificationState.value = VerificationState.noEnrollment;
        statusMessage.value = 'No face enrolled. Please enroll first.';
        return false;
      }
      ...
      */
    } catch (e) {
      verificationState.value = VerificationState.error;
      statusMessage.value = 'network_error_check_connection'.tr;
      debugPrint('[FaceAttendance] Template fetch error: $e');
      return false;
    }
  }

  void _retryVerification() {
    isPunchEnabled.value = false;
    _pendingImageBytes = null;
    _enrolledTemplate = null;
    _enrolledModelVersion = null;
    livenessService.reset();
    livenessService.startSession();
    verificationState.value = VerificationState.livenessChallenge;
    statusMessage.value = livenessService.getChallengeInstruction();
    detectionService.resume();
  }

  Future<void> _autoDetermineCheckType() async {
    try {
      if (Get.isRegistered<HrPortalController>()) {
        final hrController = Get.find<HrPortalController>();
        if (hrController.lastPunches.isNotEmpty) {
          final lastPunch = hrController.lastPunches.first.type;
          checkType.value = lastPunch == 'In' ? 'O' : 'I';
          return;
        }
      }
    } catch (_) {}
    checkType.value = 'I'; // Default to Punch In if no history or error
  }

  /// Called when employee taps PUNCH IN / PUNCH OUT.
  /// Only reachable after full verification pipeline succeeds.
  Future<void> submitPunch(String type) async {
    if (!isPunchEnabled.value || _hasSubmitted || isProcessing.value) return;
    if (_pendingImageBytes == null) return;

    _hasSubmitted = true; // Duplicate submission prevention
    isProcessing.value = true;
    // type is already '0' (In) or '1' (Out) from the UI buttons
    checkType.value = type;
    verificationState.value = VerificationState.punching;
    statusMessage.value = 'submitting_attendance'.tr;

    await _submitLegacyMultipart(_pendingImageBytes!);
  }

  Future<void> _submitLegacyMultipart(List<int> imageBytes) async {
    try {
      final userName       = GetStorage().read('username') ?? '';
      final instanceName   = GetStorage().read('instanceName') ?? '';
      
      String langCode = '1';
      if (Get.isRegistered<LanguageController>()) {
        langCode = Get.find<LanguageController>().currentLangCode.toString();
      }

      final uri = Uri.parse(ApiEndpoints.markAttendancev2);
      final request = http.MultipartRequest('POST', uri);

      request.fields['usrEmail']      = userName;
      request.fields['instanceName']  = instanceName;
      // checkType.value is already '0' (In) or '1' (Out) — pass it directly!
      request.fields['checktype']     = checkType.value;
      request.fields['Devicename']    = 'Face Detection Mobile'; // The ID backend will use for the badge!
      request.fields['deviceinfo']    = await securityService.buildDeviceMetadata();
      request.fields['locationinfo']  = _cachedLocationMeta;
      request.fields['Lang']          = langCode;

      // Attach the selfie taken during liveness verification!
      request.files.add(
        http.MultipartFile.fromBytes(
          'punchimage', 
          imageBytes,
          contentType: MediaType('image', 'jpeg'),
          filename: 'face_punch.jpg'
        ),
      );

      final ioClient = HttpClient()..badCertificateCallback = (_, __, ___) => true;
      final client = io_client.IOClient(ioClient);
      http.StreamedResponse? resp;
      try {
        resp = await client.send(request).timeout(const Duration(seconds: 30));
      } finally {
        client.close();
      }

      final body = await resp.stream.bytesToString();
      debugPrint('[FaceAttendance] MarkAttendancev2 ${resp.statusCode}: $body');

      if (resp.statusCode == 200) {
        final clean = body.replaceAll('"', '').trim();
        final parts = clean.split('|');
        final ok = parts[0].toLowerCase() == 'true' || clean.toLowerCase().contains('success');
        final msg = parts.length > 1 ? parts[1].trim() : null;
        if (ok) {
          verificationState.value = VerificationState.success;
          statusMessage.value = msg ?? 'attendance_marked_success'.tr;
          _pendingImageBytes = null;
          
          try {
            if (Get.isRegistered<HrPortalController>()) {
              final hrController = Get.find<HrPortalController>();
              final now = DateTime.now();
              hrController.lastPunches.insert(0, PunchRecord(
                type: checkType.value == '0' ? 'In' : 'Out', // '0'=In, '1'=Out
                time: DateFormat('HH:mm:ss').format(now),
                date: DateFormat('dd MMM yyyy').format(now),
                status: 'Success',
              ));
              if (hrController.lastPunches.length > 5) hrController.lastPunches.removeLast();
              hrController.refreshData();
            }
          } catch (_) {}

          try {
            if (Get.isRegistered<HomeController>()) {
              final homeController = Get.find<HomeController>();
              homeController.fetchHomeData(silent: true);
              homeController.fetchAttendanceData(silent: true);
            }
          } catch (_) {}

          // Auto-navigate back to Home after 2 seconds so user sees the success message
          Future.delayed(const Duration(seconds: 2), () {
            if (Get.isRegistered<HomeController>()) {
              Get.find<HomeController>().changeTab(0);
            }
            Get.until((route) => route.settings.name == AppRoutes.home);
          });
        } else {
          verificationState.value = VerificationState.error;
          statusMessage.value = msg ?? 'server_rejected_punch'.tr;
          _hasSubmitted = false;
        }
      } else {
        verificationState.value = VerificationState.error;
        statusMessage.value = 'server_error'.tr;
        _hasSubmitted = false;
      }
    } catch (e) {
      debugPrint('[FaceAttendance] Error submitting punch: $e');
      verificationState.value = VerificationState.error;
      statusMessage.value = 'server_error'.tr;
      _hasSubmitted = false;
    } finally {
      isProcessing.value = false;
    }
  }

  @override
  void onClose() {
    _clockTimer?.cancel();
    cameraService.dispose();
    detectionService.dispose();
    embeddingService.dispose();
    livenessService.reset();
    // Security: clear all in-memory biometric data on close
    _enrolledTemplate = null;
    _enrolledModelVersion = null;
    _pendingImageBytes = null;
    // Resume BLE scanning now that camera resources are freed
    try { FlutterBackgroundService().invoke('resumeScan'); } catch (_) {}
    super.onClose();
  }
}
