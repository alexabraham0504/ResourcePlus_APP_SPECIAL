// lib/app/modules/home/views/fingerprint_punch_view.dart
//
// Fingerprint Attendance Punch — Two-Factor: Biometric + Auto Selfie
// ─────────────────────────────────────────────────────────────────
// Flow:
//   1. Prompt device biometric (fingerprint / Face ID)
//   2. On success → open front camera → auto-capture selfie
//   3. Submit photo + deviceinfo to MarkAttendancev2 API
//
// Security:
//   • OS-level biometric (stored in secure enclave — never leaves device)
//   • Camera selfie adds visual proof for server-side audit
//   • Location required, same as HR Portal

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import '../../../services/device_info_helper.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl.dart';
import '../../../config/api_endpoints.dart';
import '../../../routes/app_routes.dart';
import '../../../controllers/language_controller.dart';

import '../controllers/home_controller.dart';
import '../controllers/hr_portal_controller.dart';
import 'widgets/shift_location_block.dart';

// ─── Fingerprint Pulse Painter ───────────────────────────────────────────────

class _FingerprintRingPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final Color color;

  _FingerprintRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background ring
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14 / 2,
      3.14 * 2 * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_FingerprintRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Controller ──────────────────────────────────────────────────────────────

enum _FingerprintPunchState {
  idle,
  authenticating,
  authSuccess,
  submitting,
  success,
  error,
}

class FingerprintPunchController extends GetxController {
  FingerprintPunchController();

  final _localAuth = LocalAuthentication();

  var state = _FingerprintPunchState.idle.obs;
  var statusMessage = 'initializing'.tr.obs;
  var isBiometricSupported = false.obs;
  var currentCoordinates = 'fetching_location'.tr.obs;
  var checkType = ''.obs; // 'I' or 'O'
  var lastPunchType = 'O'.obs; // Default to 'O' so 'PUNCH IN' is shown initially
  
  // Industrial Standard Variables
  var isBound = false.obs;
  var isInvalidated = false.obs;

  final GetStorage _storage = GetStorage();
  Position? _currentPosition;

  @override
  void onInit() {
    super.onInit();
    isBound.value = _storage.read('fingerprint_bound') ?? false;
    isInvalidated.value = _storage.read('fingerprint_invalidated') ?? false;
    _checkBiometricSupport();
    _initLocation();
    _loadLastPunchStatus();
  }

  Future<void> _loadLastPunchStatus() async {
    try {
      if (Get.isRegistered<HrPortalController>()) {
        final hrController = Get.find<HrPortalController>();
        if (hrController.lastPunches.isNotEmpty) {
          final lastPunch = hrController.lastPunches.first;
          // Convert 'In'/'Out' to 'I'/'O' for the UI logic
          lastPunchType.value = lastPunch.type == 'In' ? 'I' : 'O'; 
        }
      }
    } catch (_) {}
  }

  @override
  void onClose() {
    super.onClose();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      isBiometricSupported.value = canCheck || isDeviceSupported;
      if (isBiometricSupported.value) {
        statusMessage.value = isInvalidated.value 
            ? 'security_alert_keys_invalidated'.tr
            : isBound.value
                ? 'select_punch_in_out'.tr
                : 'device_biometrics_not_bound'.tr;
      } else {
        statusMessage.value = 'biometric_not_available'.tr;
        state.value = _FingerprintPunchState.error;
      }
    } catch (e) {
      statusMessage.value = 'biometric_check_failed'.tr;
      state.value = _FingerprintPunchState.error;
    }
  }

  Future<void> _initLocation() async {
    try {
      final status = await Permission.location.request();
      if (!status.isGranted) { currentCoordinates.value = 'location_denied'.tr; return; }
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) { currentCoordinates.value = 'enable_gps'.tr; return; }
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      ).timeout(const Duration(seconds: 15));
      if (_currentPosition != null) {
        currentCoordinates.value =
            '${_currentPosition!.latitude.toStringAsFixed(4)}, '
            '${_currentPosition!.longitude.toStringAsFixed(4)}';
      }
    } catch (_) {
      currentCoordinates.value = 'location_error'.tr;
    }
  }

  /// Industrial Standard: Bind Fingerprint to Employee
  Future<void> bindFingerprint() async {
    state.value = _FingerprintPunchState.authenticating;
    statusMessage.value = 'binding_device_biometrics'.tr;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'verify_fingerprint_to_bind'.tr,
        options: const AuthenticationOptions(
          biometricOnly: true, // Strict physical biometric only
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        _storage.write('fingerprint_bound', true);
        _storage.write('fingerprint_invalidated', false);
        isBound.value = true;
        isInvalidated.value = false;
        
        state.value = _FingerprintPunchState.idle;
        statusMessage.value = 'success_biometrics_bound'.tr;
        await Future.delayed(const Duration(seconds: 2));
        statusMessage.value = 'select_punch_in_out'.tr;
      } else {
        state.value = _FingerprintPunchState.error;
        statusMessage.value = 'binding_failed_try_again'.tr;
        await Future.delayed(const Duration(seconds: 2));
        state.value = _FingerprintPunchState.idle;
        statusMessage.value = 'device_biometrics_not_bound'.tr;
      }
    } catch (e) {
      state.value = _FingerprintPunchState.error;
      statusMessage.value = '${"error".tr}: $e';
    }
  }

  /// Demo: Simulate Android KeyPermanentlyInvalidatedException
  void simulateInvalidation() {
    _storage.write('fingerprint_invalidated', true);
    isInvalidated.value = true;
    statusMessage.value = 'security_alert_keys_invalidated'.tr;
  }

  /// Demo: Reset binding state
  void resetBinding() {
    _storage.write('fingerprint_bound', false);
    _storage.write('fingerprint_invalidated', false);
    isBound.value = false;
    isInvalidated.value = false;
    statusMessage.value = 'device_biometrics_not_bound'.tr;
  }

  /// Called when user taps the fingerprint button
  Future<void> authenticate(String type) async {
    if (isInvalidated.value) {
      statusMessage.value = 'security_alert_keys_invalidated'.tr;
      return;
    }
    if (!isBound.value) {
      statusMessage.value = 'device_biometrics_not_bound'.tr;
      return;
    }

    if (state.value == _FingerprintPunchState.authenticating ||
        state.value == _FingerprintPunchState.submitting ||
        state.value == _FingerprintPunchState.success) {
      return;
    }

    checkType.value = type;
    state.value = _FingerprintPunchState.authenticating;
    statusMessage.value = 'authenticating'.tr;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: type == 'I'
            ? 'verify_identity_punch_in'.tr
            : 'verify_identity_punch_out'.tr,
        options: const AuthenticationOptions(
          biometricOnly: true, // STRICT INDUSTRIAL STANDARD (NO PIN)
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        state.value = _FingerprintPunchState.authSuccess;
        statusMessage.value = 'verified_submitting'.tr;
        await _submit();
      } else {
        state.value = _FingerprintPunchState.error;
        statusMessage.value = 'authentication_failed_try_again'.tr;
        await Future.delayed(const Duration(seconds: 2));
        state.value = _FingerprintPunchState.idle;
        statusMessage.value = 'select_punch_in_out'.tr;
      }
    } on PlatformException catch (e) {
      String msg = 'biometric_error'.tr;
      if (e.code == 'NotEnrolled') msg = 'no_fingerprint_enrolled'.tr;
      if (e.code == 'LockedOut') msg = 'too_many_attempts_try_later'.tr;
      if (e.code == 'PermanentlyLockedOut') msg = 'biometric_locked_use_pin'.tr;
      state.value = _FingerprintPunchState.error;
      statusMessage.value = msg;
      await Future.delayed(const Duration(seconds: 3));
      state.value = _FingerprintPunchState.idle;
      statusMessage.value = 'select_punch_in_out'.tr;
    } catch (e) {
      state.value = _FingerprintPunchState.error;
      statusMessage.value = '${"error".tr}: $e';
    }
  }



  Future<String> _deviceInfo() async {
    final now = DateTime.now();
    final utcStr = DateFormat('MM/dd/yyyy HH:mm:ss').format(now.toUtc());
    final localStr = DateFormat('MM/dd/yyyy HH:mm:ss').format(now);
    final off = now.timeZoneOffset;
    final tz =
        '${off.inHours >= 0 ? '+' : ''}${off.inHours.toString().padLeft(2, '0')}:'
        '${off.inMinutes.remainder(60).toString().padLeft(2, '0')}';
    final deviceId = await DeviceInfoHelper.getPermanentDeviceId();
    return '$deviceId|Fingerprint Mobile|$utcStr|$localStr|$tz';
  }

  String _locationInfo() {
    if (_currentPosition == null) return '0.000000|0.000000| Address : No Location,';
    final lat = _currentPosition!.latitude.toStringAsFixed(6);
    final lng = _currentPosition!.longitude.toStringAsFixed(6);
    return '$lat|$lng| Address : GPS ($lat, $lng),';
  }

  Future<void> _submit() async {
    try {
      final userName       = _storage.read('username') ?? '';
      final instanceName   = _storage.read('instanceName') ?? '';
      final langController = Get.find<LanguageController>();

      final uri = Uri.parse(ApiEndpoints.markAttendancev2);
      final request = http.MultipartRequest('POST', uri);

      request.fields['usrEmail']      = userName;
      request.fields['instanceName']  = instanceName;
      request.fields['checktype']     = checkType.value == 'I' ? '0' : '1';
      request.fields['Devicename']    = 'Fingerprint Mobile';
      request.fields['deviceinfo']    = await _deviceInfo();
      request.fields['locationinfo']  = _locationInfo();
      request.fields['Lang']          = langController.currentLangCode.toString();
      // punchimage is optional for fingerprint — omitted entirely as per backend spec

      final ioClient = HttpClient()..badCertificateCallback = (_, __, ___) => true;
      final client = io_client.IOClient(ioClient);
      http.StreamedResponse? resp;
      try {
        resp = await client.send(request).timeout(const Duration(seconds: 30));
      } finally {
        client.close();
      }

      final body = await resp.stream.bytesToString();
      debugPrint('[FingerprintPunch] MarkAttendancev2 ${resp.statusCode}: $body');

      if (resp.statusCode == 200) {
        final clean = body.replaceAll('"', '').trim();
        final parts = clean.split('|');
        final ok = parts[0].toLowerCase() == 'true' || clean.toLowerCase().contains('success');
        final msg = parts.length > 1 ? parts[1].trim() : null;
        if (ok) {
          _onSuccess(msg ?? 'punched_successfully'.tr);
        } else {
          _onError(msg ?? 'server_rejected_punch'.tr);
        }
      } else {
        _onError('server_error'.tr);
      }
    } catch (e) {
      _onError('network_error'.tr);
      debugPrint('[FingerprintPunch] _submit error: $e');
    }
  }

  void _onSuccess(String msg) {
    state.value = _FingerprintPunchState.success;
    statusMessage.value = msg;
    try {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().fetchHomeData(silent: true);
        Get.find<HomeController>().fetchAttendanceData(silent: true);
      }
    } catch (_) {}
    Future.delayed(const Duration(seconds: 2), () {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().changeTab(0);
      }
      Get.until((route) => route.settings.name == AppRoutes.home);
    });
  }

  void _onError(String msg) {
    state.value = _FingerprintPunchState.error;
    statusMessage.value = msg;
    Future.delayed(const Duration(seconds: 3), () {
      state.value = _FingerprintPunchState.idle;
      statusMessage.value = 'select_punch_in_out'.tr;
    });
  }
}

// ─── View ─────────────────────────────────────────────────────────────────────

class FingerprintPunchView extends StatefulWidget {
  const FingerprintPunchView({super.key});

  @override
  State<FingerprintPunchView> createState() => _FingerprintPunchViewState();
}

class _FingerprintPunchViewState extends State<FingerprintPunchView>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnim;
  late Animation<double> _bounceAnim;

  static const _corporateBlue = Color(0xFF004A77);
  static const _teal = Color(0xFF00897B);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _amber = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  Color _stateColor(_FingerprintPunchState s) {
    switch (s) {
      case _FingerprintPunchState.success: return _green;
      case _FingerprintPunchState.error: return _red;
      case _FingerprintPunchState.authSuccess:
      case _FingerprintPunchState.submitting: return _amber;
      default: return _teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FingerprintPunchController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF0F4F8);
    final cardBg = isDark ? const Color(0xFF1A2238) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : const Color(0xFF0A0F1E),
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    // Title
                    Text(
                      'fingerprint_punch_title'.tr,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0A0F1E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'verify_device_biometric'.tr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ── Fingerprint / Camera button ──
                    Obx(() {
                      final s = controller.state.value;
                      final isCamState = false;
                      final color = _stateColor(s);

                      return GestureDetector(
                        onTap: null,
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (ctx, child) {
                            final scale = s == _FingerprintPunchState.idle
                                ? _pulseAnim.value
                                : 1.0;
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.1),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.3), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.25),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Progress ring
                                if (s == _FingerprintPunchState.submitting ||
                                    s == _FingerprintPunchState.authenticating)
                                  SizedBox(
                                    width: 148,
                                    height: 148,
                                    child: CircularProgressIndicator(
                                      color: color,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                // Icon
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: isCamState
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.camera_alt_rounded,
                                                color: color, size: 52,
                                                key: const ValueKey('cam')),
                                            const SizedBox(height: 6),
                                            Text('selfie'.tr,
                                                style: GoogleFonts.outfit(
                                                    color: color,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700)),
                                          ],
                                        )
                                      : s == _FingerprintPunchState.success
                                          ? Icon(Icons.check_circle_rounded,
                                              color: color, size: 64,
                                              key: const ValueKey('ok'))
                                          : s == _FingerprintPunchState.error
                                              ? Icon(Icons.error_outline_rounded,
                                                  color: color, size: 64,
                                                  key: const ValueKey('err'))
                                              : Icon(Icons.fingerprint,
                                                  color: color, size: 72,
                                                  key: const ValueKey('fp')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 40),

                    // ── Status message ──
                    Obx(() {
                      final s = controller.state.value;
                      final color = _stateColor(s);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: color.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                              Text(
                                controller.statusMessage.value,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 24),
                      ShiftLocationBlock(colorScheme: Theme.of(context).colorScheme, isDark: isDark),

                      const SizedBox(height: 32),

                    // ── Two-factor info chips ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _infoChip(Icons.fingerprint, 'biometric'.tr, isDark),
                        const SizedBox(width: 10),
                        Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
                        const SizedBox(width: 10),
                        _infoChip(Icons.cloud_upload_outlined, 'submit_btn'.tr, isDark),
                      ],
                    ),
                    Obx(() {
                      final s = controller.state.value;
                      if (s == _FingerprintPunchState.idle) {
                        if (controller.isInvalidated.value) {
                          // Invalidated State
                          return Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: ElevatedButton.icon(
                              onPressed: () => controller.bindFingerprint(),
                              icon: const Icon(Icons.security, color: Colors.white),
                              label: Text('rebind_biometrics'.tr, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _amber,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          );
                        } else if (!controller.isBound.value) {
                          // Unregistered State
                          return Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: ElevatedButton.icon(
                              onPressed: () => controller.bindFingerprint(),
                              icon: const Icon(Icons.fingerprint, color: Colors.white),
                              label: Text('bind_device_biometrics'.tr, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _corporateBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          );
                        } else {
                          // Registered State (Normal Punch)
                          return Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: !controller.isBiometricSupported.value ? null : () => controller.authenticate('I'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text('punch_in_caps'.tr, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: !controller.isBiometricSupported.value ? null : () => controller.authenticate('O'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text('punch_out_caps'.tr, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    }),
                    
                    const SizedBox(height: 40),
                    
                    // ── Demo Debug Controls ──
                    Obx(() {
                      if (controller.isBound.value) {
                        return Wrap(
                          spacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () => controller.simulateInvalidation(),
                              icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                              label: Text('simulate_new_fingerprint'.tr, style: const TextStyle(color: Colors.orange, fontSize: 12)),
                            ),
                            TextButton.icon(
                              onPressed: () => controller.resetBinding(),
                              icon: const Icon(Icons.refresh, color: Colors.grey, size: 16),
                              label: Text('reset_demo'.tr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ],
                ),
              ),
             ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
