import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

import '../services/background_tracking_service.dart';
import '../config/bluetooth_attendance_config.dart';
import '../utils/ble_compatibility_check.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../home/views/widgets/shift_location_block.dart';

// ─── Radar Painter ─────────────────────────────────────────────────────────
class _RadarPainter extends CustomPainter {
  final double sweep;
  _RadarPainter({required this.sweep});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 16) return; // Prevent native renderer crash on zero size

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(0.0, size.width / 2 - 8);
    const primary = Color(0xFF0D96F2);

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(
        center,
        radius * i / 4,
        Paint()
          ..color = primary.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    final sweepAngle = sweep * math.pi * 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradientPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - math.pi / 2,
        endAngle: sweepAngle,
        colors: [primary.withValues(alpha: 0.0), primary.withValues(alpha: 0.6)],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawArc(rect, sweepAngle - math.pi / 2, math.pi / 2, true, gradientPaint);

    canvas.drawLine(
      center,
      Offset(center.dx + radius * math.cos(sweepAngle), center.dy + radius * math.sin(sweepAngle)),
      Paint()
        ..color = primary
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.sweep != sweep;
}

// ─── Beacon Model ────────────────────────────────────────────────────────────
class _BeaconItem {
  final String name;
  final String mac;
  final int rssi;
  final String site;
  final String zone;
  final DateTime lastSeen;
  bool isPunchedIn;
  bool? isRegistered; // null = checking, true = registered, false = not registered

  _BeaconItem({
    required this.name,
    required this.mac,
    required this.rssi,
    required this.site,
    required this.zone,
    required this.lastSeen,
    this.isPunchedIn = false,
    this.isRegistered,
  });
}

// ─── View ─────────────────────────────────────────────────────────────────────
class BluetoothPunchView extends StatefulWidget {
  const BluetoothPunchView({super.key});

  @override
  State<BluetoothPunchView> createState() => _BluetoothPunchViewState();
}

class _BluetoothPunchViewState extends State<BluetoothPunchView>
    with SingleTickerProviderStateMixin {

  late final AnimationController _radarController;
  final Map<String, _BeaconItem> _beacons = {};
  final List<Map<String, dynamic>> _punchLog = [];

  StreamSubscription? _beaconSub;
  StreamSubscription? _punchSub;
  StreamSubscription? _punchErrorSub;
  StreamSubscription? _btStateSub;
  StreamSubscription? _locStateSub;

  final _bgService = BackgroundTrackingService();
  bool _serviceRunning = false;
  bool _isBluetoothOn = true; // Assume true until checked
  bool _isLocationOn = true;
  bool _isRegistered = false;
  bool _disposed = false; // stops recursive _checkServiceStatus on page close
  
  final Map<String, String> _lastRangeState = {};

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _isRegistered = GetStorage().read('bt_device_registered') ?? false;

    // CRITICAL: Push credentials to background service isolate.
    // The background isolate has its own Dart VM and cannot read the main app's GetStorage.
    // We must explicitly send credentials every time the app opens.
    // Push credentials AFTER service starts to avoid race condition where
    // the background isolate hasn't registered updateCredentials listener yet.
    _checkServiceStatus();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _pushCredentialsToBackgroundService();
    });
    _listenToBackgroundService();
    _listenToHardwareStates();

    // Run compatibility check after first frame. Requests battery
    // optimization exemption on Samsung/Xiaomi/Oppo/Vivo/OnePlus so the
    // background scanner is never killed by aggressive manufacturer Doze.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BleCompatibilityCheck.run(context);
    });
  }

  void _pushCredentialsToBackgroundService() {
    final storage = GetStorage();
    final username = (storage.read('username') ?? '').toString();
    final email = (storage.read('email') ?? '').toString();
    final instanceName = (storage.read('instanceName') ?? '').toString();
    FlutterBackgroundService().invoke('updateCredentials', {
      'username': username,
      'email': email,
      'instanceName': instanceName,
    });
    debugPrint('[BLE UI] Pushed credentials to service: username=$username instanceName=$instanceName');
  }

  final Set<String> _checkingBeacons = {};
  // Permanently tracks beacons whose status was FULLY checked (prevents infinite API loop)
  final Set<String> _checkedBeacons = {};
  final Map<String, DateTime> _registrationAttempts = {};
  String? _cachedDeviceId;

  Future<String> _getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      _cachedDeviceId = (await deviceInfo.androidInfo).id;
    } else if (Platform.isIOS) {
      _cachedDeviceId = (await deviceInfo.iosInfo).identifierForVendor ?? 'UNKNOWN-iOS';
    } else {
      _cachedDeviceId = 'UNKNOWN';
    }
    return _cachedDeviceId!;
  }

  /// Returns true if the beacon is already registered in local cache.
  /// Returns null if we have no local info (API check still needed).
  bool? _isRegisteredLocally(String beaconId) {
    final registered = List<String>.from(GetStorage().read('registered_beacons') ?? []);
    if (registered.contains(beaconId)) return true;
    return null; // unknown — let the API check decide
  }

  Future<void> _checkRegistrationStatusForBeacon(String mac, String beaconId) async {
    final now = DateTime.now();
    final lastAttempt = _registrationAttempts[mac];
    if (lastAttempt != null && now.difference(lastAttempt).inSeconds < 30) return;
    _registrationAttempts[mac] = now;
    _checkingBeacons.add(mac);
    bool isReg = false;
    try {
      final deviceId = await _getDeviceId();
      isReg = await BluetoothAttendanceConfig.checkRegistration(deviceId, beaconId: beaconId);
    } catch (e) {
      debugPrint('Registration check error for $beaconId: $e');
      // On API failure (timeout / network error), fall back to local cache.
      // This prevents the "Checking registration..." spinner from freezing forever
      // for users on slow networks (e.g., Riyadh, remote India).
      isReg = _isRegisteredLocally(beaconId) ?? false;
    } finally {
      _checkingBeacons.remove(mac);
      _checkedBeacons.add(mac); // CRITICAL: always clears the spinner
    }

    final storage = GetStorage();
    List<String> registered = List<String>.from(storage.read('registered_beacons') ?? []);
    bool updated = false;
    if (isReg && !registered.contains(beaconId)) {
      registered.add(beaconId);
      updated = true;
    } else if (!isReg && registered.contains(beaconId)) {
      registered.remove(beaconId);
      updated = true;
    }

    if (updated) {
      storage.write('registered_beacons', registered);
      FlutterBackgroundService().invoke('updateRegisteredBeacons', {'beacons': registered});
    }

    if (mounted) {
      setState(() {
        if (_beacons.containsKey(mac)) {
          _beacons[mac]!.isRegistered = isReg;
        }
      });
    }
  }

  Future<void> _performRegistrationForBeacon(String mac, String beaconId) async {
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    try {
      final deviceId = await _getDeviceId();
      
      final success = await BluetoothAttendanceConfig.registerDevice(deviceId, beaconId: beaconId);
      Get.back(); // close loading
      
      if (success) {
        final storage = GetStorage();
        List<String> registered = List<String>.from(storage.read('registered_beacons') ?? []);
        if (!registered.contains(beaconId)) {
          registered.add(beaconId);
          storage.write('registered_beacons', registered);
          FlutterBackgroundService().invoke('updateRegisteredBeacons', {'beacons': registered});
        }
        
        if (mounted) {
          setState(() {
            if (_beacons.containsKey(mac)) {
              _beacons[mac]!.isRegistered = true;
            }
          });
        }
        Get.snackbar('Success', 'Registered successfully to $beaconId!', backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('Error', 'Registration failed. Please try again.', backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.back();
      debugPrint('API Register Error: $e');
    }
  }
  void _listenToHardwareStates() {
    _btStateSub = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() => _isBluetoothOn = state == BluetoothAdapterState.on);
      }
    });

    // Wrapped in try-catch: Google Play Services can throw when Bluetooth
    // and Location are toggled simultaneously (ApiException code 20)
    Geolocator.isLocationServiceEnabled().then((enabled) {
      if (mounted) setState(() => _isLocationOn = enabled);
    }).catchError((e) {
      // Play Services disconnected momentarily — assume location is enabled
      // and let the stream listener update the state when it stabilises
      debugPrint('[BLE] isLocationServiceEnabled failed (Play Services): $e');
    });

    _locStateSub = Geolocator.getServiceStatusStream().listen(
      (status) {
        if (mounted) {
          setState(() => _isLocationOn = status == ServiceStatus.enabled);
        }
      },
      onError: (e) {
        debugPrint('[BLE] Location service stream error: $e');
      },
    );
  }


  Future<void> _checkServiceStatus() async {
    if (_disposed || !mounted) return;
    final running = await _bgService.isRunning();
    if (_disposed || !mounted) return;
    setState(() => _serviceRunning = running);
    // Keep checking every 3 seconds
    Future.delayed(const Duration(seconds: 3), _checkServiceStatus);
  }

  void _listenToBackgroundService() {
    // Live beacon list from background service
    _beaconSub = _bgService.beaconStream.listen((data) {
      if (data == null || !mounted) return;
      final beaconList = data['beacons'] as List<dynamic>? ?? [];
      setState(() {
        final activeKeys = beaconList.map((b) => b['macAddress'] as String? ?? '').toSet();
        _beacons.removeWhere((key, _) => !activeKeys.contains(key));
        for (final b in beaconList) {
          final map = b as Map<String, dynamic>;
          final mac = (map['macAddress'] ?? '') as String;
          final rssiVal = (map['rssi'] ?? -100) as int;
          final beaconNameStr = (map['name'] ?? 'Unknown') as String;
          
          final existing = _beacons[mac];
          _beacons[mac] = _BeaconItem(
            name: beaconNameStr,
            mac: mac,
            rssi: rssiVal,
            site: (map['site'] ?? '') as String,
            zone: (map['zone'] ?? '') as String,
            lastSeen: DateTime.tryParse((map['lastSeen'] ?? '') as String) ?? DateTime.now(),
            isPunchedIn: existing?.isPunchedIn ?? false,
            // Preserve API result if we have one. Otherwise, check local cache first
            // so already-registered beacons never flash "Tap to Register".
            isRegistered: existing?.isRegistered ?? _isRegisteredLocally(beaconNameStr),
          );
          
          // Only call the API if we have NEVER gotten a result for this beacon yet.
          // _checkedBeacons stores beacons that were FULLY checked (even if result is false).
          // This prevents the infinite HTTP loop caused by isRegistered resetting to null each update.
          if (existing?.isRegistered == null && !_checkingBeacons.contains(mac) && !_checkedBeacons.contains(mac)) {
            _checkRegistrationStatusForBeacon(mac, beaconNameStr);
          }
          
          final currentRange = _rssiLabel(rssiVal);
          _lastRangeState[mac] = currentRange;
        }
        // Expire beacons not seen for > 30s
        final now = DateTime.now();
        _beacons.removeWhere((_, b) => now.difference(b.lastSeen).inSeconds > 30);
      });
    });

    // Punch IN/OUT events
    _punchSub = _bgService.punchStream.listen((data) {
      if (data == null || !mounted) return;
      final mac = (data['beaconMac'] ?? '') as String;
      final type = (data['type'] ?? '') as String;
      setState(() {
        if (_beacons.containsKey(mac)) {
          _beacons[mac]!.isPunchedIn = type == 'PUNCH_IN';
        }
        _punchLog.insert(0, data);
        if (_punchLog.length > 20) _punchLog.removeLast();
      });
    });
    // Punch Error events
    _punchErrorSub = _bgService.punchErrorStream.listen((data) {
      if (data == null || !mounted) return;
      final beaconName = (data['beaconName'] ?? '') as String;
      final errorMsg = (data['error'] ?? 'Unknown Error') as String;
      
      Get.snackbar(
        'Punch Rejected',
        'Backend rejected punch at $beaconName: $errorMsg',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _radarController.dispose();
    _beaconSub?.cancel();
    _punchSub?.cancel();
    _punchErrorSub?.cancel();
    _btStateSub?.cancel();
    _locStateSub?.cancel();
    super.dispose();
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -60) return const Color(0xFF10B981);
    if (rssi >= -75) return Colors.orange;
    return Colors.redAccent;
  }

  String _rssiLabel(int rssi) {
    if (rssi >= -60) return 'very_close';
    if (rssi >= -75) return 'near';
    return 'far';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor1 = isDark ? const Color(0xFF050D1A) : const Color(0xFFF0F4FF);
    final bgColor2 = isDark ? const Color(0xFF0A1931) : const Color(0xFFFFFFFF);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.5,
            colors: [bgColor2, bgColor1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Get.back(),
                    ),
                    const Spacer(),
                    // Service status pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _serviceRunning
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _serviceRunning ? const Color(0xFF10B981) : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _serviceRunning ? 'scanner_active'.tr : 'scanner_off'.tr,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _serviceRunning ? const Color(0xFF10B981) : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'beacon_scanner_title'.tr,
                style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              Text(
                'auto_detecting_beacons'.tr,
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
              ),

              const SizedBox(height: 10),

              // ── Radar & Disabled Overlay ──────────────────────────────────
              Expanded(
                flex: 1,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _radarController,
                    builder: (context, _) => SizedBox(
                      width: double.infinity,
                      height: 220,
                      child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Normal Radar
                      AnimatedOpacity(
                        opacity: (_isBluetoothOn && _isLocationOn) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              painter: _RadarPainter(sweep: _radarController.value),
                              size: const Size(160, 160),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _beacons.isEmpty
                                      ? Icons.bluetooth_searching
                                      : Icons.bluetooth_connected,
                                  color: const Color(0xFF0D96F2),
                                  size: 32,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_beacons.length} ${_beacons.length == 1 ? 'beacon_word'.tr : 'beacons_word'.tr}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF0D96F2),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Disabled Overlay
                      AnimatedOpacity(
                        opacity: (!_isBluetoothOn || !_isLocationOn) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: (!_isBluetoothOn || !_isLocationOn) ? _buildDisabledOverlay() : const SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ShiftLocationBlock(
              colorScheme: Theme.of(context).colorScheme, 
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 10),

          // ── Bottom Panel ───────────────────────────────────────────────
          Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Detected beacons header
                      Row(
                        children: [
                          const Icon(Icons.radar, size: 16, color: Color(0xFF0D96F2)),
                          const SizedBox(width: 6),
                          Text(
                            'nearby_beacons'.tr,
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '${_beacons.length} ${'found'.tr}',
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Beacon list - takes up remaining space
                      Expanded(
                        child: _beacons.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bluetooth_disabled, color: Colors.grey[400], size: 36),
                                      const SizedBox(height: 6),
                                      Text(
                                        'no_beacons_detected'.tr,
                                        style: GoogleFonts.outfit(color: Colors.grey, fontStyle: FontStyle.italic),
                                      ),
                                      Text(
                                        'turn_on_nrf_connect'.tr,
                                        style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[400]),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _beacons.length,
                                itemBuilder: (_, i) => _buildBeaconCard(_beacons.values.elementAt(i), isDark),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeaconCard(_BeaconItem beacon, bool isDark) {
    final color = _rssiColor(beacon.rssi);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: beacon.isPunchedIn
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : color.withValues(alpha: 0.2),
          width: beacon.isPunchedIn ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bluetooth, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      beacon.name,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      beacon.site.isNotEmpty ? '${beacon.site} — ${beacon.zone}' : beacon.mac,
                      style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${beacon.rssi} dBm',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_rssiLabel(beacon.rssi).tr, style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey)),
                  if (beacon.isPunchedIn) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '✅ IN',
                        style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
      if (beacon.isRegistered != null) ...[
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 8),
        Row(
          children: [
            if (beacon.isRegistered == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 14),
                    const SizedBox(width: 4),
                    Text('Registered', style: GoogleFonts.outfit(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              InkWell(
                onTap: () => _performRegistrationForBeacon(beacon.mac, beacon.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_rounded, color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      Text('Tap to Register', style: GoogleFonts.outfit(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ] else ...[
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text('Checking registration...', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    ],
  ),
);
  }

  Widget _buildDisabledOverlay() {
    final missingService = !_isBluetoothOn ? 'Bluetooth' : 'Location';
    final isBoth = !_isBluetoothOn && !_isLocationOn;
    final message = isBoth ? 'bluetooth_location_off'.tr : '$missingService ${'is_off'.tr}';
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isBluetoothOn) const Icon(Icons.bluetooth_disabled, color: Colors.redAccent, size: 28),
                if (!_isBluetoothOn && !_isLocationOn) const SizedBox(width: 8),
                if (!_isLocationOn) const Icon(Icons.location_off, color: Colors.redAccent, size: 28),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                if (!_isBluetoothOn) {
                  AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                } else if (!_isLocationOn) {
                  AppSettings.openAppSettings(type: AppSettingsType.location);
                }
              },
              icon: const Icon(Icons.settings, size: 18),
              label: Text('turn_on_settings'.tr),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
