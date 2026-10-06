// lib/app/modules/home/views/face_detection_punch_view.dart
//
// Face Detection Attendance Punch
// ─────────────────────────────────────────────────────────
// Uses the front camera + Google ML Kit to detect the employee's face live.
// When a face is clearly centred inside the oval guide, it auto-captures
// a selfie and calls the same MarkAttendancev2 API as the HR Portal.

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import '../../../services/device_info_helper.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../../config/api_endpoints.dart';
import '../../../controllers/language_controller.dart';
import '../controllers/home_controller.dart';

// ─── Oval Overlay Painter ─────────────────────────────────────────────────────

class _FaceOvalPainter extends CustomPainter {
  final bool faceDetected;
  final double animValue;

  _FaceOvalPainter({required this.faceDetected, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final ovalW = size.width * 0.62;
    final ovalH = ovalW * 1.35;
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: ovalW,
      height: ovalH,
    );

    // Darken everything outside oval
    final cutout = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(cutout, Paint()..color = Colors.black.withValues(alpha: 0.55));

    // Oval border — green when face detected, white when not
    final borderColor = faceDetected
        ? Color.lerp(const Color(0xFF10B981), const Color(0xFF34D399), animValue)!
        : Color.lerp(Colors.white54, Colors.white, animValue)!;

    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = faceDetected ? 3.5 : 2.0,
    );
  }

  @override
  bool shouldRepaint(_FaceOvalPainter old) =>
      old.faceDetected != faceDetected || old.animValue != animValue;
}

// ─── Controller ──────────────────────────────────────────────────────────────

class FaceDetectionPunchController extends GetxController {
  FaceDetectionPunchController();

  CameraController? cameraController;
  final isCameraInitialized = false.obs;
  final isFaceDetected = false.obs;
  var isProcessing = false.obs;
  var punchSuccess = false.obs;
  var punchError = false.obs;
  var statusMessage = 'Initializing...'.obs;
  final currentCoordinates = 'Locating...'.obs;

  final GetStorage _storage = GetStorage();
  Position? _currentPosition;

  bool _isDetecting = false;
  bool _isClosed = false;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0); // throttle

  // Lazy — do NOT create FaceDetector in the constructor.
  // ML Kit loads a native library synchronously which blocks the UI thread
  // and causes "Skipped 96 frames" → app crash. Create it only when needed.
  FaceDetector? _faceDetector;
  FaceDetector get faceDetector {
    _faceDetector ??= FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.25,
      ),
    );
    return _faceDetector!;
  }

  @override
  void onInit() {
    super.onInit();
    try {
      FlutterBackgroundService().invoke('pauseScan');
    } catch (_) {}
    // Defer ALL heavy init by 2 frames so the page route transition
    // finishes rendering first (avoids "Skipped N frames" → OOM crash).
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_isClosed) _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    if (_isClosed) return;
    await Permission.camera.request();
    await Permission.location.request();
    if (_isClosed) return;
    _initLocation();
    _initCamera();
  }

  @override
  void onClose() {
    _isClosed = true;
    _faceDetector?.close();
    cameraController?.stopImageStream();
    cameraController?.dispose();
    try {
      FlutterBackgroundService().invoke('resumeScan');
    } catch (_) {}
    super.onClose();
  }

  Future<void> _initLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) { currentCoordinates.value = 'Enable GPS'; return; }
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (_currentPosition != null) {
        currentCoordinates.value =
            '${_currentPosition!.latitude.toStringAsFixed(4)}, '
            '${_currentPosition!.longitude.toStringAsFixed(4)}';
      }
    } catch (e) {
      currentCoordinates.value = 'Location error';
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      cameraController = CameraController(
        front,
        ResolutionPreset.low, // Keep native buffer small to avoid OOM on low-RAM devices
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await cameraController!.initialize();
      isCameraInitialized.value = true;
      statusMessage.value = 'position_face_guide'.tr;
      _startFaceDetection();
    } catch (e) {
      statusMessage.value = 'Camera error';
    }
  }

  void _startFaceDetection() {
    cameraController?.startImageStream((CameraImage image) async {
      // Throttle to max 2fps — face detection doesn't need more,
      // and every skipped frame = ~460KB of NativeAlloc not allocated.
      final now = DateTime.now();
      if (now.difference(_lastFrameTime).inMilliseconds < 500) return;
      if (_isDetecting || isProcessing.value) return;
      _lastFrameTime = now;
      _isDetecting = true;
      try {
        final faces = await _detectFaces(image);
        isFaceDetected.value = faces.isNotEmpty;
      } catch (_) {
      } finally {
        _isDetecting = false;
      }
    });
  }

  Future<List<Face>> _detectFaces(CameraImage image) async {
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
      return await faceDetector.processImage(inputImage);
    } catch (_) {
      return [];
    }
  }

  Future<void> capturePunch(String checkType) async {
    if (isProcessing.value) return;
    if (!isFaceDetected.value) {
      statusMessage.value = 'Face not detected!';
      return;
    }
    isProcessing.value = true;
    try {
      final xFile = await cameraController?.takePicture();
      if (xFile == null) { _onError('Capture failed'); return; }

      Uint8List bytes = await xFile.readAsBytes();
      bytes = await FlutterImageCompress.compressWithList(
          bytes, minHeight: 1280, minWidth: 720, quality: 85);

      await _submit(bytes, checkType);
    } catch (e) {
      _onError('Error: $e');
    }
  }

  Future<String> _deviceInfo() async {
    final now = DateTime.now();
    final utcStr = DateFormat('MM/dd/yyyy HH:mm:ss').format(now.toUtc());
    final deviceId = await DeviceInfoHelper.getPermanentDeviceId();
    return '$deviceId|Face Detection Mobile|$utcStr|$utcStr|+00:00';
  }

  String _locationInfo() {
    if (_currentPosition == null) return '0.000000|0.000000| Address : No Location,';
    final lat = _currentPosition!.latitude.toStringAsFixed(6);
    final lng = _currentPosition!.longitude.toStringAsFixed(6);
    return '$lat|$lng| Address : GPS ($lat, $lng),';
  }

  Future<void> _submit(Uint8List imageBytes, String checkType) async {
    try {
      final empNumber = _storage.read('username') ?? '';
      final instanceName = _storage.read('instanceName') ?? '';
      
      LanguageController langController = Get.find<LanguageController>();

      final request = http.MultipartRequest('POST', Uri.parse(ApiEndpoints.markAttendancev2));
      request.fields['usrEmail'] = empNumber;
      request.fields['instanceName'] = instanceName;
      request.fields['checktype'] = checkType;
      request.fields['Devicename'] = 'Face Detection Mobile';
      request.fields['deviceinfo'] = await _deviceInfo();
      request.fields['locationinfo'] = _locationInfo();
      request.fields['Lang'] = langController.currentLangCode.toString();
      request.files.add(http.MultipartFile.fromBytes(
        'punchimage', imageBytes,
        contentType: MediaType('image', 'jpeg'),
        filename: 'face_punch.jpg',
      ));

      final ioClient2 = HttpClient()..badCertificateCallback = (_, __, ___) => true;
      final client = io_client.IOClient(ioClient2);
      http.StreamedResponse? resp;
      try { resp = await client.send(request); } finally { client.close(); }

      final body = await resp.stream.bytesToString();
      if (resp.statusCode == 200) {
        final clean = body.replaceAll('"', '').trim();
        final parts = clean.split('|');
        final ok = parts[0].toLowerCase() == 'true' || clean.toLowerCase().contains('success');
        final msg = parts.length > 1 ? parts[1].trim() : null;
        if (ok) {
          _onSuccess(msg ?? 'Punched Successfully');
        } else {
          _onError(msg ?? 'Server rejected');
        }
      } else {
        _onError('Server error ${resp.statusCode}');
      }
    } catch (e) {
      _onError('Network error');
      debugPrint('Submit error: $e');
    }
  }

  void _onSuccess(String msg) {
    punchSuccess.value = true;
    statusMessage.value = msg;
    isProcessing.value = false;
    try {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().fetchHomeData(silent: true);
        Get.find<HomeController>().fetchAttendanceData(silent: true);
      }
    } catch (_) {}
    Future.delayed(const Duration(seconds: 2), () => Get.back());
  }

  void _onError(String msg) {
    punchError.value = true;
    statusMessage.value = msg;
    isProcessing.value = false;
    isProcessing.value = false;
    isFaceDetected.value = false;
    Future.delayed(const Duration(seconds: 2), () {
      punchError.value = false;
      statusMessage.value = 'position_face_guide'.tr;
      _startFaceDetection();
    });
  }
}

// ─── View ─────────────────────────────────────────────────────────────────────

class FaceDetectionPunchView extends StatefulWidget {
  const FaceDetectionPunchView({super.key});

  @override
  State<FaceDetectionPunchView> createState() => _FaceDetectionPunchViewState();
}

class _FaceDetectionPunchViewState extends State<FaceDetectionPunchView>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FaceDetectionPunchController>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          Obx(() {
            if (!controller.isCameraInitialized.value ||
                controller.cameraController == null) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }
            final prev = controller.cameraController!.value.previewSize;
            return SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: prev?.height ?? size.width,
                  height: prev?.width ?? size.height,
                  child: CameraPreview(controller.cameraController!),
                ),
              ),
            );
          }),

          // Oval overlay
          Obx(() {
            final isFaceDetected = controller.isFaceDetected.value;
            return AnimatedBuilder(
              animation: _pulseAnim,
              builder: (ctx, _) => CustomPaint(
                painter: _FaceOvalPainter(
                  faceDetected: isFaceDetected,
                  animValue: _pulseAnim.value,
                ),
                size: size,
              ),
            );
          }),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),

          // Instruction text (center top of oval area)
          Positioned(
            top: size.height * 0.1,
            left: 0,
            right: 0,
            child: Text(
              'Face Detection',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              top: false,
              child: Obx(() {
                final isSuccess = controller.punchSuccess.value;
                final isError = controller.punchError.value;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? _green.withValues(alpha: 0.95)
                        : isError
                            ? _red.withValues(alpha: 0.95)
                            : Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSuccess
                          ? _green
                          : isError
                              ? _red
                              : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (controller.isProcessing.value)
                            const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          else if (isSuccess)
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 24)
                          else if (isError)
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.white, size: 24)
                          else
                            AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (ctx, _) => Icon(
                                Icons.face_retouching_natural,
                                color: Colors.white
                                    .withValues(alpha: 0.6 + 0.4 * _pulseAnim.value),
                                size: 24,
                              ),
                            ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              controller.statusMessage.value,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isSuccess && !isError) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.white54, size: 13),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                controller.currentCoordinates.value,
                                style: GoogleFonts.outfit(
                                    color: Colors.white60, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!isSuccess && !isError) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: controller.isProcessing.value ? null : () => controller.capturePunch('I'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('PUNCH IN', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: controller.isProcessing.value ? null : () => controller.capturePunch('O'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('PUNCH OUT', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
