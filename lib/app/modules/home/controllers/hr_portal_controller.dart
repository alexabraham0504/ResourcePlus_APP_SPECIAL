import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'package:http_parser/http_parser.dart';
import 'package:get_storage/get_storage.dart';
import '../../../services/api_service.dart';
import '../../../controllers/language_controller.dart';
import '../../../config/api_endpoints.dart';
import 'home_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';

class HrPortalController extends GetxController {
  // Camera
  CameraController? cameraController;
  final isCameraInitialized = false.obs;
  final isCameraPermissionGranted = false.obs;

  // Time
  final currentTime = ''.obs;
  Timer? _timeTimer;

  // Location
  final currentCoordinates = 'Loading...'.obs;
  final isLocationPermissionGranted = false.obs;
  Position? _currentPosition;
  Timer? _locationTimer;

  // Attendance
  final isProcessingAttendance = false.obs;
  final isProcessingIn = false.obs;
  final isProcessingOut = false.obs;
  final lastPunches = <PunchRecord>[].obs;
  final currentShift =
      'Shift error'.obs; // Default shift, will be fetched from API
  final isLoadingPunches = false.obs;
  final hasPunchesError = false.obs;

  final Dio _dio = ApiService().dio;
  final GetStorage _storage = GetStorage();
  
  final zoomDrawerController = ZoomDrawerController();

  // Prevent multiple simultaneous image captures
  bool _isCapturingImage = false;

  // Get platform name safely (works on web and native)
  String _getPlatformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name.toLowerCase();
  }

  // Get or create device ID
  String _getDeviceId() {
    String? deviceId = _storage.read('deviceId_v2');
    if (deviceId == null || deviceId.isEmpty) {
      // Keep Device ID short (max 15 chars) to prevent SQL truncation issues on the backend
      final randomNum = (DateTime.now().millisecondsSinceEpoch % 100000).toString();
      deviceId = 'MOB_$randomNum';
      _storage.write('deviceId_v2', deviceId);
    }
    return deviceId;
  }

  // Get device name
  String _getDeviceName() {
    if (kIsWeb) return 'Web Browser';
    if (defaultTargetPlatform == TargetPlatform.android) return 'Android Mobile';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'iOS Mobile';
    return defaultTargetPlatform.name;
  }

  // Safe snackbar helper — avoids "No Overlay widget found" crash
  void _showSnackbar(
    String title,
    String message, {
    SnackPosition position = SnackPosition.BOTTOM,
    Color? backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    try {
      final context = Get.context;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor ?? Colors.white)),
                Text(message, style: TextStyle(color: textColor ?? Colors.white)),
              ],
            ),
            backgroundColor: backgroundColor ?? Colors.grey[800],
            duration: duration,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Snackbar error (suppressed): $e — title: $title, msg: $message');
    }
  }

  /// Premium animated center popup for validation errors.
  /// Shows a beautiful dialog with icon, gradient header, and smooth animations.
  void _showValidationPopup({
    required IconData icon,
    required String title,
    required String message,
    Color accentColor = const Color(0xFFEF4444),
  }) {
    Get.dialog(
      _AnimatedValidationDialog(
        icon: icon,
        title: title,
        message: message,
        accentColor: accentColor,
      ),
      barrierDismissible: true,
      barrierColor: Colors.black54,
    );
  }

  // Capture image from camera and return as raw bytes directly
  // Using XFile.readAsBytes() uses the native platform channels and completely 
  // bypasses Android 14 Scoped Storage/cache file lock errors that block dart:io File access!
  Future<Uint8List?> _captureImageBytes() async {
    if (_isCapturingImage) {
      debugPrint('Image capture already in progress');
      return null;
    }

    try {
      _isCapturingImage = true;

      if (cameraController == null || !cameraController!.value.isInitialized) {
        debugPrint('Camera not initialized for image capture');
        return null;
      }

      // Take picture using the native plugin
      final XFile image = await cameraController!.takePicture();

      // On Android 14, the hardware camera HAL often writes asynchronously.
      // takePicture() resolves before the JPEG is actually written to the cache!
      // If we read it immediately, we might read 0 bytes or a corrupted 2KB stub.
      // We MUST wait for the file size to stabilize and be a valid JPEG size (> 10KB).
      int previousSize = -1;
      int currentSize = await image.length();
      int retries = 0;
      
      // while ((currentSize != previousSize || currentSize < 10000) && retries < 15) {
      //   await Future.delayed(const Duration(milliseconds: 250));
      // After — longer wait, more retries, higher minimum for Samsung
      while ((currentSize != previousSize || currentSize < 50000) && retries < 40) {
        await Future.delayed(const Duration(milliseconds: 300));
        previousSize = currentSize;
        currentSize = await image.length();
        retries++;
        debugPrint('Waiting for Android 14 camera buffer flush... size: $currentSize bytes (retry $retries)');
      }

      // Read bytes safely now that the native hardware is done flushing
      final Uint8List bytes = await image.readAsBytes();
      
      if (bytes.isNotEmpty) {
        debugPrint('Image successfully read into memory via XFile: ${bytes.length} bytes');
        
        // Try to clean up the temporary native cache file safely
        try { File(image.path).delete(); } catch (_) {}
        
        return bytes;
      } else {
        debugPrint('XFile returned 0 bytes');
        return null;
      }
    } catch (e) {
      debugPrint('Error capturing image bytes: $e');
      return null;
    } finally {
      _isCapturingImage = false;
    }
  }



  // Build device info string: "deviceId|deviceName|UTC-PunchTime|LocalPunchTime|TimeZone"
  String _buildDeviceInfo() {
    final now = DateTime.now();
    final utcTime = now.toUtc();
    final localTime = now;

    // Use MM/dd/yyyy format to prevent parsing errors on the backend when day > 12
    final utcTimeStr = DateFormat('MM/dd/yyyy HH:mm:ss').format(utcTime);
    final localTimeStr = DateFormat('MM/dd/yyyy HH:mm:ss').format(localTime);

    // Get timezone offset
    final timeZoneOffset = now.timeZoneOffset;
    final hours = timeZoneOffset.inHours;
    final minutes = timeZoneOffset.inMinutes.remainder(60);
    final timeZoneStr =
        '${hours >= 0 ? '+' : ''}${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';

    return '${_getDeviceId()}|${_getDeviceName()}|$utcTimeStr|$localTimeStr|$timeZoneStr';
  }

  // Build location info string: "Latitude|Longitude| Address : Lat/Lng,"
  String _buildLocationInfo() {
    if (_currentPosition == null) {
      return '0.000000|0.000000| Address : 0/0,';
    }

    final lat = _currentPosition!.latitude.toStringAsFixed(6);
    final lng = _currentPosition!.longitude.toStringAsFixed(6);

    return '$lat|$lng| Address : $lat/$lng,';
  }

  @override
  void onInit() {
    super.onInit();
    _initializeCamera();
    _startTimeUpdates();
    _initializeLocation();
    fetchLastFivePunches();
    fetchShiftDetails();
  }

  @override
  void onClose() {
    _timeTimer?.cancel();
    _locationTimer?.cancel();
    cameraController?.dispose();
    super.onClose();
  }

  // Initialize Camera
  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      isCameraPermissionGranted.value = cameraStatus.isGranted;

      if (!isCameraPermissionGranted.value) {
        _showSnackbar(
          'Camera Permission',
          'Camera permission is required for HR Portal',
        );
        return;
      }

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showSnackbar(
          'Camera Error',
          'No cameras available on this device',
        );
        return;
      }

      // Use front camera if available, otherwise use first camera
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Initialize camera controller with high resolution for better clarity
      // Using high provides 720p/1080p which looks significantly better when scaled in the UI
      cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            ImageFormatGroup.jpeg, // Use JPEG to reduce buffer size
      );

      await cameraController!.initialize();

      // Double-check initialization before setting flag
      if (cameraController != null && cameraController!.value.isInitialized) {
        isCameraInitialized.value = true;
      } else {
        debugPrint(
          'Camera initialization completed but not properly initialized',
        );
        isCameraInitialized.value = false;
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      isCameraInitialized.value = false;

      // Dispose controller on error to prevent further issues
      try {
        await cameraController?.dispose();
        cameraController = null;
      } catch (disposeError) {
        debugPrint('Error disposing camera controller: $disposeError');
      }

      _showSnackbar(
        'Camera Error',
        'Failed to initialize camera: $e',
      );
    }
  }

  // Start time updates
  void _startTimeUpdates() {
    _updateTime();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    currentTime.value = DateFormat('HH:mm:ss').format(now);
  }

  // Initialize Location
  Future<void> _initializeLocation() async {
    try {
      // Request location permission
      final locationStatus = await Permission.location.request();
      isLocationPermissionGranted.value = locationStatus.isGranted;

      if (!isLocationPermissionGranted.value) {
        currentCoordinates.value = 'Permission denied';
        return;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        currentCoordinates.value = 'Location services disabled';
        return;
      }

      // Get current position
      await _updateLocation();

      // Update location every 30 seconds
      _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _updateLocation();
      });
    } catch (e) {
      debugPrint('Error initializing location: $e');
      currentCoordinates.value = 'Error getting location';
    }
  }

  Future<void> _updateLocation() async {
    try {
      // Add timeout to prevent hanging if location services are flaky
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10), // 10 second timeout
        ),
      ).timeout(const Duration(seconds: 12), onTimeout: () {
        debugPrint('Location request timed out');
        return Future.error('Location timeout');
      });

      if (_currentPosition != null) {
        currentCoordinates.value =
            '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
      if (currentCoordinates.value == 'Loading...') {
        currentCoordinates.value = 'Unable to get location';
      }
      
      // Try to get last known position as fallback
      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          _currentPosition = lastPosition;
          currentCoordinates.value =
              '${lastPosition.latitude.toStringAsFixed(6)}, ${lastPosition.longitude.toStringAsFixed(6)} (Cached)';
        }
      } catch (_) {}
    }
  }


  // Fetch last 5 punches from API
  Future<void> fetchLastFivePunches() async {
    try {
      isLoadingPunches.value = true;
      hasPunchesError.value = false;

      final instanceName = GetStorage().read('instanceName');
      final userName = GetStorage().read('username');
      final userEmail = GetStorage().read('email');
      // Use username (e.g. 'rplusadmin') for usrEmail, same as MarkAttendance
      final usrEmailValue = (userName != null && userName.toString().isNotEmpty)
          ? userName.toString()
          : (userEmail ?? '').toString();

      if (instanceName == null || instanceName.toString().isEmpty) {
        debugPrint('Instance name not found');
        hasPunchesError.value = true;
        isLoadingPunches.value = false;
        return;
      }

      if (usrEmailValue.isEmpty) {
        debugPrint('User credentials not found');
        hasPunchesError.value = true;
        isLoadingPunches.value = false;
        return;
      }

      debugPrint('Fetching punches: instanceName=$instanceName, usrEmail=$usrEmailValue');

      final response = await _dio.get(
        ApiEndpoints.getLastFivePunches,
        queryParameters: {
          'instanceName': instanceName,
          'usrEmail': usrEmailValue,
          'L': 1,
        },
      );

      if (response.statusCode == 200) {
        var responseData = response.data;
      
        // Try parsing if it's a string
        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (e) {
            debugPrint('Failed to decode string response: $e');
          }
        }
        
        // Extract list if it's a map containing a specific key
        List<dynamic>? punchesData;
        if (responseData is List) {
          punchesData = responseData;
        } else if (responseData is Map) {
          if (responseData.containsKey('data') && responseData['data'] is List) {
            punchesData = responseData['data'];
          } else if (responseData.containsKey('Punches') && responseData['Punches'] is List) {
            punchesData = responseData['Punches'];
          } else if (responseData.containsKey('LastFivePunches') && responseData['LastFivePunches'] is List) {
            punchesData = responseData['LastFivePunches'];
          } else if (responseData.containsKey('Table') && responseData['Table'] is List) {
            punchesData = responseData['Table'];
          }
        }
        
          if (punchesData != null) {
            final List<PunchRecord> punches = [];

            for (var punchData in punchesData) {
            try {
              final punchTimeDevice =
                  punchData['punchtime_device']?.toString() ?? '';
              final punchType = punchData['punch_type']?.toString() ?? '';

              if (punchTimeDevice.isNotEmpty) {
                // Parse the date/time from format: "01/12/2025 01:44:46 PM"
                DateTime? parsedDate;
                String dateStr = '';
                String timeStr = '';

                try {
                  // The server returns dates in multiple possible formats.
                  // Try each one until we find a match.
                  final formats = [
                    'dd/MM/yyyy HH:mm:ss',     // Expected primary format
                    'dd/MM/yyyy hh:mm:ss a',   // Expected with AM/PM
                    'MM/dd/yyyy HH:mm:ss',     // US format fallback
                    'MM/dd/yyyy hh:mm:ss a',   // US format with AM/PM
                    'yyyy-MM-dd HH:mm:ss',     // ISO-like format
                  ];

                  for (final fmt in formats) {
                    try {
                      parsedDate = DateFormat(fmt).parseStrict(punchTimeDevice);
                      break; // Found a match
                    } catch (_) {}
                  }

                  if (parsedDate != null) {
                    dateStr = DateFormat('dd MMM yyyy').format(parsedDate);
                    timeStr = DateFormat('HH:mm:ss').format(parsedDate);
                  } else {
                    debugPrint('Could not parse date: $punchTimeDevice');
                    final now = DateTime.now();
                    dateStr = DateFormat('dd MMM yyyy').format(now);
                    timeStr = DateFormat('HH:mm:ss').format(now);
                  }
                } catch (e) {
                  debugPrint('Error parsing date: $e');
                  final now = DateTime.now();
                  dateStr = DateFormat('dd MMM yyyy').format(now);
                  timeStr = DateFormat('HH:mm:ss').format(now);
                }

                // Map punch_type to type (IN -> In, OUT -> Out)
                String type = punchType.toUpperCase() == 'IN' ? 'In' : 'Out';

                // Determine status based on isrejected
                final isRejected =
                    punchData['isrejected']?.toString().toUpperCase() ?? 'NO';
                final status = isRejected == 'YES' ? 'Rejected' : 'Success';

                punches.add(
                  PunchRecord(
                    type: type,
                    time: timeStr,
                    date: dateStr,
                    status: status,
                  ),
                );
              }
            } catch (e) {
              debugPrint('Error parsing punch record: $e');
              continue;
            }
          }

            // 3. Remove duplicates (keep local ones as priority)
            final uniquePunches = <String, PunchRecord>{};
            for (var p in punches) {
              final key = '${p.date}_${p.time}_${p.type}';
              if (!uniquePunches.containsKey(key)) {
                uniquePunches[key] = p;
              }
            }
            
            final finalList = uniquePunches.values.toList();
            
            // 4. Chronological sort (Latest at the TOP)
            finalList.sort((a, b) {
              try {
                // Try parsing with the display format "dd MMM yyyy HH:mm:ss"
                final dateTimeA = DateFormat('dd MMM yyyy HH:mm:ss').parse('${a.date} ${a.time}');
                final dateTimeB = DateFormat('dd MMM yyyy HH:mm:ss').parse('${b.date} ${b.time}');
                return dateTimeB.compareTo(dateTimeA);
              } catch (e) {
                try {
                  // Fallback: simple date comparison if time parsing fails
                  final dateA = DateFormat('dd MMM yyyy').parse(a.date);
                  final dateB = DateFormat('dd MMM yyyy').parse(b.date);
                  return dateB.compareTo(dateA);
                } catch (e2) {
                  return 0;
                }
              }
            });
            
            debugPrint('Sorted punches: ${finalList.map((p) => '${p.date} ${p.time}').toList()}');
            lastPunches.value = finalList.take(5).toList();
          } else {
          hasPunchesError.value = true;
          debugPrint('Unexpected response format from API: $responseData');
        }
      } else {
        hasPunchesError.value = true;
        debugPrint('Unexpected response status code from API: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching last 5 punches: $e');
      hasPunchesError.value = true;
      _showSnackbar(
        'Error',
        'Failed to load punches: ${e.toString()}',
      );
    } finally {
      isLoadingPunches.value = false;
    }
  }

  // Fetch shift details from API
  Future<void> fetchShiftDetails() async {
    try {
      final instanceName = GetStorage().read('instanceName');
      final userEmail = GetStorage().read('email');
      final userName = GetStorage().read('username');

      if (instanceName == null || instanceName.toString().isEmpty) {
        debugPrint('fetchShiftDetails: Instance name not found');
        currentShift.value = 'Instance error';
        return;
      }

      final usrEmailValue = (userName != null && userName.toString().isNotEmpty)
          ? userName.toString()
          : (userEmail != null && userEmail.toString().isNotEmpty)
              ? userEmail.toString()
              : null;

      if (usrEmailValue == null) {
        debugPrint('fetchShiftDetails: No user credentials');
        currentShift.value = 'User error';
        return;
      }

      debugPrint('fetchShiftDetails: instance=$instanceName, user=$usrEmailValue');

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getShiftDetails,
        queryParameters: {
          'instanceName': instanceName,
          'usrEmail': usrEmailValue,
          'Lang': languageController.currentLangCode,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        var responseData = response.data;
        
        if (responseData is String) {
          try {
            String cleanData = responseData.toString().replaceAll('\uFEFF', '').trim();
            if (cleanData.startsWith('"') && cleanData.endsWith('"')) {
              try {
                cleanData = jsonDecode(cleanData);
              } catch (_) {
                cleanData = cleanData.substring(1, cleanData.length - 1).replaceAll('\\"', '"');
              }
            }
            responseData = jsonDecode(cleanData);
          } catch (e) {
            debugPrint('fetchShiftDetails: String decode failed: $e');
          }
        }
        
        List<dynamic>? shiftData;
        if (responseData is List) {
          shiftData = responseData;
        } else if (responseData is Map) {
          if (responseData.containsKey('data') && responseData['data'] is List) {
            shiftData = responseData['data'];
          } else if (responseData.containsKey('ShiftDetails') && responseData['ShiftDetails'] is List) {
            shiftData = responseData['ShiftDetails'];
          } else if (responseData.containsKey('Table') && responseData['Table'] is List) {
            shiftData = responseData['Table'];
          }
        }

        if (shiftData != null && shiftData.isNotEmpty) {
          final shiftInfo = shiftData[0];
          final shiftName = shiftInfo['ShiftName']?.toString() ?? 
                           shiftInfo['shift_name']?.toString() ?? 
                           shiftInfo['shiftname']?.toString();

          if (shiftName != null && shiftName.isNotEmpty) {
            currentShift.value = shiftName;
          } else {
            debugPrint('fetchShiftDetails: ShiftName missing in data');
            currentShift.value = 'No shift assigned';
          }
        } else {
          debugPrint('fetchShiftDetails: No shift data found');
          currentShift.value = 'No shift';
        }
      } else {
        debugPrint('fetchShiftDetails: HTTP ${response.statusCode}');
        currentShift.value = 'Server error';
      }
    } catch (e) {
      debugPrint('Error fetching shift details: $e');
      currentShift.value = 'Conn error';
    }
  }


  // Mark attendance - In
  Future<void> markAttendanceIn() async {
    await _markAttendance(checkType: 0);
  }

  // Mark attendance - Out
  Future<void> markAttendanceOut() async {
    await _markAttendance(checkType: 1);
  }

  // Mark attendance API call
  // Uses the new multipart endpoint deployed on the original MarkAttendance route
  Future<void> _markAttendance({required int checkType}) async {
    final isProcessingFlag = checkType == 0 ? isProcessingIn : isProcessingOut;
    if (isProcessingFlag.value || isProcessingAttendance.value) return;

    try {
      isProcessingAttendance.value = true;
      isProcessingFlag.value = true;

      // Get stored username — prefer username, fall back to email
      final userName = GetStorage().read('username');
      final userEmail = GetStorage().read('email');
      if ((userName == null || userName.toString().isEmpty) &&
          (userEmail == null || userEmail.toString().isEmpty)) {
        _showSnackbar('Error', 'User credentials not found');
        return;
      }
      final usrEmailValue = (userName != null && userName.toString().isNotEmpty)
          ? userName.toString()
          : userEmail.toString();

      // --- STRICT VALIDATION ---
      // 1. Camera Validation
      if (!isCameraPermissionGranted.value) {
        _showValidationPopup(
          icon: Icons.camera_alt_outlined,
          title: 'camera_permission_title'.tr,
          message: 'camera_permission_msg'.tr,
          accentColor: const Color(0xFFF59E0B),
        );
        return;
      }
      if (!isCameraInitialized.value) {
        _showValidationPopup(
          icon: Icons.videocam_off_outlined,
          title: 'camera_not_ready_title'.tr,
          message: 'camera_not_ready_msg'.tr,
          accentColor: const Color(0xFFF59E0B),
        );
        return;
      }

      // 2. Location Validation
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showValidationPopup(
          icon: Icons.location_off_outlined,
          title: 'location_disabled_title'.tr,
          message: 'location_disabled_msg'.tr,
          accentColor: const Color(0xFFEF4444),
        );
        return;
      }
      if (!isLocationPermissionGranted.value) {
        _showValidationPopup(
          icon: Icons.location_disabled_outlined,
          title: 'location_permission_title'.tr,
          message: 'location_permission_msg'.tr,
          accentColor: const Color(0xFFEF4444),
        );
        return;
      }

      // Ensure location is updated
      if (_currentPosition == null) {
        await _updateLocation();
      }
      
      // Final Location Check
      if (_currentPosition == null) {
        _showValidationPopup(
          icon: Icons.gps_off_outlined,
          title: 'gps_signal_lost_title'.tr,
          message: 'gps_signal_lost_msg'.tr,
          accentColor: const Color(0xFFEF4444),
        );
        return;
      }
      // -------------------------

      // Capture image from camera natively to memory bytes
      final originalBytes = await _captureImageBytes();
      if (originalBytes == null) {
        _showSnackbar('Error', 'Failed to capture image');
        return;
      }

      final languageController = Get.find<LanguageController>();
      final rawInstanceName = GetStorage().read('instanceName') ?? '';

      // ── MarkAttendancev2 Multipart Request ──
      bool success = false;
      String? message;

      try {
        debugPrint('Trying MarkAttendancev2 (http.MultipartRequest)...');
        
        // We use native HttpClient to bypass Dio's multipart formatting quirks
        // which were triggering a 415 MediaTypeFormatter bug on the IIS server.
        final uri = Uri.parse(ApiEndpoints.markAttendancev2);
        final request = http.MultipartRequest('POST', uri);

        // Add text fields
        request.fields['usrEmail'] = usrEmailValue;
        request.fields['instanceName'] = rawInstanceName;
        request.fields['checktype'] = checkType.toString();
        request.fields['Devicename'] = _getDeviceName();
        request.fields['deviceinfo'] = _buildDeviceInfo();
        request.fields['locationinfo'] = _buildLocationInfo();
        request.fields['Lang'] = languageController.currentLangCode.toString();

        // Determine if front camera was used to handle mirroring correctly
        bool isFrontCamera = false;
        if (cameraController != null && cameraController!.description.lensDirection == CameraLensDirection.front) {
          isFrontCamera = true;
        }

        // Process image in isolate to crop exactly to 16:9 and mirror if needed
        var imageBytes = originalBytes;
        try {
          final processedBytes = await compute(_processImageIsolate, {
            'bytes': originalBytes,
            'isFrontCamera': isFrontCamera,
          });
          
          if (processedBytes != null && processedBytes.isNotEmpty) {
            imageBytes = processedBytes;
          }
        } catch (e) {
          debugPrint('Image processing isolate failed: $e');
        }

        final fileSize = imageBytes.length;
        final magicBytes = imageBytes.take(4).toList();
        debugPrint('Original size: ${originalBytes.length}, Processed size: $fileSize bytes, magic=[${magicBytes.map((b) => '0x${b.toRadixString(16)}').join(', ')}]');

        // Add image bytes with explicit content type
        request.files.add(
          http.MultipartFile.fromBytes(
            'punchimage',
            imageBytes,
            contentType: MediaType('image', 'jpeg'),
            filename: 'punch.jpg',
          )
        );

        debugPrint('Sending to $uri');
        debugPrint('Fields: ${request.fields}');
        
        // Use IOClient to allow bad certs but still use the clean http package
        final ioClient = HttpClient();
        ioClient.badCertificateCallback = (cert, host, port) => true;
        final customClient = io_client.IOClient(ioClient);

        http.StreamedResponse? streamedResponse;
        try {
          streamedResponse = await customClient.send(request);
        } finally {
          customClient.close();
        }
        final responseBody = await streamedResponse.stream.bytesToString();

        debugPrint('Response: status=${streamedResponse.statusCode}, body=$responseBody');

        if (streamedResponse.statusCode == 200) {
          final responseStr = responseBody.replaceAll('"', '').trim();
          final parts = responseStr.split('|');
          success = parts[0].toLowerCase() == 'true' || responseStr.toLowerCase().contains('success');
          message = parts.length > 1 ? parts[1].trim() : null;
          
          if (!success) {
             debugPrint('Server rejected: $responseStr');
          }
        } else {
          debugPrint('Failed with status ${streamedResponse.statusCode}');
        }
      } catch (e) {
        debugPrint('Request failed: $e');
      }

      // Note: No file cleanup needed since we used native memory bytes via XFile!

      // ── Handle result ──
      if (success) {
        _showSnackbar(
          'Success',
          message ?? (checkType == 0 ? 'Attendance marked as In' : 'Attendance marked as Out'),
          backgroundColor: Colors.green,
          textColor: Colors.white,
          duration: const Duration(seconds: 2),
        );

        final now = DateTime.now();
        lastPunches.insert(0, PunchRecord(
          type: checkType == 0 ? 'In' : 'Out',
          time: DateFormat('HH:mm:ss').format(now),
          date: DateFormat('dd MMM yyyy').format(now),
          status: 'Success',
        ));
        if (lastPunches.length > 5) lastPunches.removeLast();

        Future.delayed(const Duration(seconds: 5), () async {
          await fetchLastFivePunches();
          try {
            final homeController = Get.find<HomeController>();
            await homeController.fetchAttendanceData();
          } catch (_) {}
        });
      } else {
        _showSnackbar('Error', message ?? 'Failed to mark attendance');
      }
    } catch (e) {
      debugPrint('Error marking attendance: $e');
      _showSnackbar('Error', 'Failed: ${e.toString().substring(0, e.toString().length.clamp(0, 100))}', backgroundColor: Colors.red);
    } finally {
      isProcessingAttendance.value = false;
      isProcessingFlag.value = false;
    }
  }
}

// Punch Record Model
class PunchRecord {
  final String type;
  final String time;
  final String date;
  final String status;

  PunchRecord({
    required this.type,
    required this.time,
    required this.date,
    required this.status,
  });
}

// Process image in isolate to prevent UI freezing
Uint8List? _processImageIsolate(Map<String, dynamic> args) {
  try {
    Uint8List bytes = args['bytes'];
    bool isFrontCamera = args['isFrontCamera'];

    // Decode the image natively
    img.Image? capturedImage = img.decodeImage(bytes);
    if (capturedImage == null) return null;

    // Apply EXIF rotation to ensure it's upright as expected by Dart
    capturedImage = img.bakeOrientation(capturedImage);

    // Front camera inherently mirrors the preview (acts like a mirror) but captures standard.
    // Since the requirement is to match EXACTLY what the user saw in the preview, we flip it horizontally.
    if (isFrontCamera) {
      capturedImage = img.flipHorizontal(capturedImage);
    }

    // Crop to match the new 3:4 (portrait) or 4:3 (landscape) aspect ratio of the UI container.
    // The UI uses AspectRatio(aspectRatio: 3 / 4 in portrait or 4 / 3 in landscape) and FittedBox(fit: BoxFit.cover).
    // This creates a center crop of the image to the target ratio.
    int imgWidth = capturedImage.width;
    int imgHeight = capturedImage.height;
    bool isImagePortrait = imgWidth < imgHeight;
    double targetRatio = isImagePortrait ? 3.0 / 4.0 : 4.0 / 3.0;
    double currentRatio = imgWidth / imgHeight;

    int cropX = 0;
    int cropY = 0;
    int cropWidth = imgWidth;
    int cropHeight = imgHeight;

    if ((currentRatio - targetRatio).abs() > 0.01) {
      if (currentRatio < targetRatio) {
        // Image is taller than target ratio (e.g. 9:16). Crop height (top and bottom).
        cropWidth = imgWidth;
        cropHeight = (imgWidth / targetRatio).round();
        cropY = ((imgHeight - cropHeight) / 2).round();
      } else {
        // Image is wider than target ratio. Crop width (left and right).
        cropHeight = imgHeight;
        cropWidth = (imgHeight * targetRatio).round();
        cropX = ((imgWidth - cropWidth) / 2).round();
      }

      capturedImage = img.copyCrop(
        capturedImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );
    }

    // Re-encode to JPEG with 85% quality to maintain proper quality as requested
    return img.encodeJpg(capturedImage, quality: 85);
  } catch (e) {
    debugPrint('Error processing image in isolate: $e');
    return null;
  }
}

/// Futuristic animated validation dialog with glowing effects, glassmorphism, and smooth animations.
class _AnimatedValidationDialog extends StatefulWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accentColor;

  const _AnimatedValidationDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.accentColor,
  });

  @override
  State<_AnimatedValidationDialog> createState() => _AnimatedValidationDialogState();
}

class _AnimatedValidationDialogState extends State<_AnimatedValidationDialog>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 36),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulseVal = _pulseController.value;
              return Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: widget.accentColor.withOpacity(0.2 + pulseVal * 0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.08 + pulseVal * 0.12),
                      blurRadius: 40 + pulseVal * 20,
                      spreadRadius: pulseVal * 6,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.accentColor.withOpacity(0.9),
                        widget.accentColor.withOpacity(0.6),
                        widget.accentColor.withOpacity(0.4),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow ring
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return Container(
                            width: 88 + _pulseController.value * 12,
                            height: 88 + _pulseController.value * 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15 + _pulseController.value * 0.1),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                      // Icon circle
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(scale: value, child: child);
                        },
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(widget.icon, color: Colors.white, size: 34),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // OK Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: widget.accentColor.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'ok'.tr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
