import 'dart:async';
import 'attendance_response.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'package:intl/intl.dart';
import '../config/bluetooth_attendance_config.dart';
import '../../../config/api_endpoints.dart';
import '../../face_attendance/repositories/mock_local_punch_repository.dart';

// ─── Data model: one detected BLE beacon ──────────────────────────────────
class DetectedBeacon {
  final String name;
  final String macAddress;
  final int rssi;
  final DateTime lastSeen;

  DetectedBeacon({
    required this.name,
    required this.macAddress,
    required this.rssi,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'macAddress': macAddress,
    'rssi': rssi,
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory DetectedBeacon.fromJson(Map<String, dynamic> json) => DetectedBeacon(
    name: (json['name'] ?? '') as String,
    macAddress: (json['macAddress'] ?? '') as String,
    rssi: (json['rssi'] ?? -100) as int,
    lastSeen:
        DateTime.tryParse((json['lastSeen'] ?? '') as String) ?? DateTime.now(),
  );
}

// ─── Service Manager ────────────────────────────────────────────────────────
class BackgroundTrackingService {
  static final BackgroundTrackingService _instance =
      BackgroundTrackingService._internal();
  factory BackgroundTrackingService() => _instance;
  BackgroundTrackingService._internal();

  Future<void> initializeService() async {
    // Request required permissions for background beacon scanning
    if (Platform.isIOS) {
      await Permission.locationAlways.request();
      await Permission.bluetooth.request();
    } else {
      await Permission.locationWhenInUse.request();
      await Permission.locationAlways.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
    }

    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'bluetooth_attendance_channel',
      'Bluetooth Attendance Tracking',
      description: 'Scanning for office beacons for automatic attendance.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Started manually after login
        isForegroundMode: true,
        notificationChannelId: 'bluetooth_attendance_channel',
        initialNotificationTitle: '📡 ResourcePlus Active',
        initialNotificationContent: 'Scanning for office beacon...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> startService() async {
    // Auto-registration has been removed. Registration now only happens securely
    // via the UI when a physical beacon is detected in range.

    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
    }
  }

  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  Future<bool> isRunning() async {
    return await FlutterBackgroundService().isRunning();
  }

  /// Stream of beacon scan updates from the background service to the UI
  Stream<Map<String, dynamic>?> get beaconStream =>
      FlutterBackgroundService().on('beaconUpdate');

  /// Stream of punch events (IN/OUT) from the background service to the UI
  Stream<Map<String, dynamic>?> get punchStream =>
      FlutterBackgroundService().on('punchEvent');

  /// Stream of new beacon detections for global popups
  Stream<Map<String, dynamic>?> get beaconDetectedStream =>
      FlutterBackgroundService().on('beaconDetected');

  /// Stream of punch errors from the background service to the UI
  Stream<Map<String, dynamic>?> get punchErrorStream =>
      FlutterBackgroundService().on('punchError');
}

// ─── iOS Background Handler ──────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ─── Main Background Isolate Entry Point ─────────────────────────────────────
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  // Stores the latest detected data for each beacon in this background isolate
  final Map<String, Map<String, dynamic>> _detectedBeacons = {};

  await GetStorage.init();

  final storage = GetStorage();
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    ),
  );

  // ── Service control commands ────────────────────────────────────────────
  if (service is AndroidServiceInstance) {
    service
        .on('setAsForeground')
        .listen((_) => service.setAsForegroundService());
    service
        .on('setAsBackground')
        .listen((_) => service.setAsBackgroundService());
  }

  service.on('updateRegisteredBeacons').listen((event) {
    if (event != null && event['beacons'] != null) {
      GetStorage().write('registered_beacons', event['beacons']);
    }
  });

  // The background isolate has a separate Dart VM — GetStorage is NOT synced with the main app.
  // The main app pushes credentials here so the background punch always has the correct values.
  service.on('updateCredentials').listen((event) {
    if (event != null) {
      if (event['username'] != null)
        GetStorage().write('username', event['username']);
      if (event['email'] != null) GetStorage().write('email', event['email']);
      if (event['instanceName'] != null)
        GetStorage().write('instanceName', event['instanceName']);
      debugPrint(
        '[BLE Service] Credentials updated: username=${event['username']} instanceName=${event['instanceName']}',
      );
    }
  });


  // ── Fetch authorized beacons from the real API ──────────────────────────
  await BluetoothAttendanceConfig.refreshBeaconsFromApi();
  debugPrint(
    '[BLE Service] Authorized beacons: ${BluetoothAttendanceConfig.authorizedBeacons.length}',
  );

  // ── State ───────────────────────────────────────────────────────────────
  final Map<String, DateTime> _beaconLastSeen = {};
  final Set<String> _punchedIn = Set<String>.from(
    storage.read('punched_in_beacons') ?? [],
  ); // MAC addresses currently punched IN
  final Set<String> _notifiedBeacons =
      {}; // MAC addresses we already notified the user about
  final Map<String, List<int>> _rssiBuffer = {}; // Store last 5 RSSI readings
  bool _isBluetoothOn = false;
  bool _isScanPausedByUi = false; // Prevents OOM when camera is open
  bool _bluetoothAdapterJustTurnedOff =
      false; // Track if adapter itself went OFF (vs beacon leaving range)
  bool _scanStartInProgress = false;
  bool _outCheckInProgress = false;
  int _lastUiUpdate = 0;
  int _lastPunchProcess = 0;
  final Set<String> _pendingIn = {};
  StreamSubscription? _scanSub;
  StreamSubscription? _adapterSub;
  StreamSubscription? _rangingSub;
  Timer? _periodicScanTimer;
  DateTime _lastAnyScanResult = DateTime.now();
  Timer? _outTimer;

  // ── Reset punch state on logout ─────────────────────────────────────────
  // When user logs out, the service keeps running but we must wipe all
  // in-memory and persisted punch state so the next user starts clean.
  service.on('resetPunchState').listen((_) {
    _punchedIn.clear();
    _pendingIn.clear();
    _detectedBeacons.clear();
    _beaconLastSeen.clear();
    _rssiBuffer.clear();
    _notifiedBeacons.clear();
    GetStorage().write('punched_in_beacons', <String>[]);
    // Clear all per-beacon debounce keys
    final storage2 = GetStorage();
    try {
      final keys = storage2.getKeys<Iterable<String>>();
      if (keys != null) {
        for (final key in List<String>.from(keys)) {
          if (key.startsWith('last_api_punch_')) storage2.remove(key);
        }
      }
    } catch (_) {}
    debugPrint('[BLE Service] Punch state reset on logout.');
  });

  service.on('stopService').listen((_) async {
    _isBluetoothOn = false;
    _periodicScanTimer?.cancel();
    _outTimer?.cancel();
    await _scanSub?.cancel();
    await _adapterSub?.cancel();
    await _rangingSub?.cancel();
    try {
      await FlutterBluePlus.stopScan();
    } finally {
      await service.stopSelf();
    }
  });

  const Duration gracePeriod = Duration(
    seconds: 30,
  ); // Allow 30s buffer for missed bluetooth packets before punching OUT
  const int rssiThreshold = -100; // Only punch in if signal is strong enough
  const int minSamples = 1; // Require only 1 scan cycle for FAST detection

  String? _cachedDeviceId;
  Future<String> _getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      _cachedDeviceId = info.id;
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      _cachedDeviceId = info.identifierForVendor ?? 'UNKNOWN-iOS';
    } else {
      _cachedDeviceId = 'UNKNOWN';
    }
    return _cachedDeviceId!;
  }

  void _processPunches(Map<String, Map<String, dynamic>> detected) async {
    final storage = GetStorage();

    // Iterate over a COPY of the entries to prevent ConcurrentModificationError
    // because this loop yields execution (await) which allows the map to be modified
    final entriesCopy = detected.entries.toList();
    for (final entry in entriesCopy) {
      final mac = entry.key;
      final beacon = entry.value;
      final seenAt = _beaconLastSeen[mac];
      if (!_isBluetoothOn ||
          _pendingIn.contains(mac) ||
          seenAt == null ||
          DateTime.now().difference(seenAt) > const Duration(seconds: 10))
        continue;

      final employeeName = storage.read('employeeName') ?? 'Employee';
      final beaconName = (beacon['name'] as String?) ?? mac;
      final name = (beacon['name'] as String?) ?? '';

      // Match against live authorized beacon list from the server.
      bool isAuthorized = BluetoothAttendanceConfig.authorizedBeacons.any((b) {
        final cleanUuid = b.uuid.replaceAll('-', '').toLowerCase();
        final cleanMac = mac
            .replaceAll(':', '')
            .replaceAll('-', '')
            .toLowerCase();
        final cleanName = name.replaceAll('-', '').toLowerCase();
        final cleanBeaconName = beaconName.replaceAll('-', '').toLowerCase();
        final cleanBeaconId = b.beaconId.replaceAll('-', '').toLowerCase();

        return cleanBeaconId == cleanBeaconName ||
            cleanBeaconId == cleanName ||
            cleanUuid == cleanMac ||
            cleanUuid == cleanBeaconName ||
            cleanUuid == cleanName;
      });

      final samples = _rssiBuffer[mac] ?? [];
      final avgRssi = samples.isEmpty
          ? -100.0
          : samples.reduce((a, b) => a + b) / samples.length;

      final registeredBeacons = List<String>.from(
        storage.read('registered_beacons') ?? [],
      );
      final isRegisteredLocally = registeredBeacons.contains(beaconName);

      // Read the true global state to prevent zombie isolates from duplicate punching
      final currentPunchedIn = List<String>.from(
        storage.read('punched_in_beacons') ?? [],
      );

      if (!currentPunchedIn.contains(mac) &&
          avgRssi >= rssiThreshold &&
          samples.length >= minSamples &&
          isAuthorized &&
          isRegisteredLocally) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final lastPunch = storage.read('last_api_punch_$mac') ?? 0;

        // GLOBAL DEBOUNCE: strictly prevent ANY punch (IN or OUT) within 60 seconds of a previous one
        if (nowMs - lastPunch < 60000) continue;
        storage.write('last_api_punch_$mac', nowMs);

        _pendingIn.add(mac);
        try {
          // Fetch heavy hardware info ONLY when we actually need to punch in
          final deviceId = await _getDeviceId();
          Position? position;
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
            );
          } catch (_) {}

          final userName = (storage.read('username') ?? '').toString();
          final email = (storage.read('email') ?? '').toString();
          final usrEmail = userName.isNotEmpty ? userName : email;
          final instanceName = (storage.read('instanceName') ?? '').toString();
          debugPrint(
            '[BLE Punch] usrEmail=$usrEmail instanceName=$instanceName',
          );

          // ── Call MarkAttendancev2 directly for Bluetooth punch ──────────
          final now = DateTime.now();
          final utcStr = DateFormat('MM/dd/yyyy HH:mm:ss').format(now.toUtc());
          final localStr = DateFormat('MM/dd/yyyy HH:mm:ss').format(now);
          final off = now.timeZoneOffset;
          final tz =
              '${off.inHours >= 0 ? '+' : ''}${off.inHours.toString().padLeft(2, '0')}:${off.inMinutes.remainder(60).toString().padLeft(2, '0')}';
          final deviceinfo = '$deviceId|Bluetooth Mobile|$utcStr|$localStr|$tz';
          final lat = position?.latitude.toStringAsFixed(6) ?? '0.000000';
          final lng = position?.longitude.toStringAsFixed(6) ?? '0.000000';
          // Put the Beacon ID in the location address so it is safely recorded without breaking SQL column length limits
          final locationinfo = '$lat|$lng| Address : BLE Beacon $beaconName,';

          final uri = Uri.parse(ApiEndpoints.markAttendancev2);
          final request = http.MultipartRequest('POST', uri);
          request.fields['usrEmail'] = usrEmail;
          request.fields['instanceName'] = instanceName;
          request.fields['checktype'] = '0'; // '0' = Punch IN
          request.fields['Devicename'] =
              'Bluetooth Mobile'; // Same pattern as 'Fingerprint Mobile' which works
          request.fields['deviceinfo'] = deviceinfo;
          request.fields['locationinfo'] = locationinfo;
          request.fields['Lang'] =
              (storage.read('currentLangCode') ??
                      storage.read('langCode') ??
                      '1')
                  .toString();
          // NOTE: punchimage intentionally omitted — same as fingerprint punch which is confirmed to work on this backend

          final ioClient = HttpClient()
            ..badCertificateCallback = (_, __, ___) => true;
          final client = io_client.IOClient(ioClient);
          late http.Response resp;
          try {
            resp = await client
                .send(request)
                .then(http.Response.fromStream)
                .timeout(const Duration(seconds: 30));
          } finally {
            client.close();
          }

          final body = resp.body;
          debugPrint('[BLE Punch] MarkAttendancev2 ${resp.statusCode}: $body');

          final ok = attendanceAccepted(resp.statusCode, body);

          if (ok) {
            _punchedIn.add(mac);
            await storage.write('punched_in_beacons', _punchedIn.toList());
            try {
              final hasPerm = await Permission.notification.isGranted;
              if (hasPerm) {
                // Use unique notification ID per event (timestamp-based) so each punch
                // shows as a separate notification instead of overwriting the previous one
                final notifId = DateTime.now().millisecondsSinceEpoch % 100000;
                flutterLocalNotificationsPlugin.show(
                  notifId,
                  '✅ Attendance: IN — $employeeName',
                  'Beacon "$beaconName" verified.',
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      'bluetooth_attendance_channel',
                      'Bluetooth Attendance Tracking',
                      icon: '@mipmap/launcher_icon',
                      importance: Importance.high,
                      priority: Priority.high,
                    ),
                  ),
                );
              }
            } catch (e) {
              debugPrint('[BLE Punch] Failed to show notification: $e');
            }

            service.invoke('punchEvent', {
              'type': 'PUNCH_IN',
              'beaconName': beaconName,
              'beaconMac': mac,
              'employeeName': employeeName,
              'timestamp': DateTime.now().toIso8601String(),
            });
          } else {
            _punchedIn.remove(mac);
            storage.write('punched_in_beacons', _punchedIn.toList());
            debugPrint('[BLE Punch] Server rejected: $body');
            service.invoke('punchError', {
              'beaconName': beaconName,
              'error': body,
            });
          }
        } catch (e) {
          _punchedIn.remove(mac);
          storage.write('punched_in_beacons', _punchedIn.toList());
          debugPrint('[BLE Punch] Error: $e');
          service.invoke('punchError', {
            'beaconName': beaconName,
            'error': e.toString(),
          });
        } finally {
          _pendingIn.remove(mac);
        }
      }
    }
  }

  // ── iOS / Native iBeacon Scan ────────────────────────────────────────────
  void _startIBeaconScan() async {
    try {
      await flutterBeacon.initializeScanning;

      final regions = BluetoothAttendanceConfig.authorizedBeacons.map((config) {
        return Region(identifier: config.beaconId, proximityUUID: config.uuid);
      }).toList();

      _rangingSub = flutterBeacon.ranging(regions).listen((
        RangingResult result,
      ) {
        for (final beacon in result.beacons) {
          final macOrId = result.region.identifier;

          _detectedBeacons[macOrId] = {
            'name': result.region.identifier,
            'macAddress': macOrId,
            'rssi': beacon.rssi,
            'lastSeen': DateTime.now().toIso8601String(),
          };
          _beaconLastSeen[macOrId] = DateTime.now();
          _rssiBuffer[macOrId] = [beacon.rssi];
        }

        if (_detectedBeacons.isNotEmpty) {
          service.invoke('beaconUpdate', {
            'beacons': _detectedBeacons.values.toList(),
          });
          _processPunches(_detectedBeacons);
        }
      });
    } catch (e) {
      print('flutter_beacon initialization failed: $e');
    }
  }

  if (Platform.isIOS) {
    _startIBeaconScan();
  }

  // ── Generic BLE Scan (Android fallback) ──────────────────────────────────

  void _runScan() async {
    if (!_isBluetoothOn ||
        _scanStartInProgress ||
        _isScanPausedByUi ||
        FlutterBluePlus.isScanningNow)
      return;

    _scanStartInProgress = true;
    try {
      await FlutterBluePlus.startScan(
        // continuousUpdates: true keeps the scan alive indefinitely.
        // Do NOT add withMsd/withNames: OS-level filters block beacons before our code sees them.
        // Do NOT add continuousDivisor > 1: it drops packets and makes the beacon appear/disappear.
        // Memory is controlled by the throttle in the scanResults listener instead.
        continuousUpdates: true,
      );
    } catch (e) {
      debugPrint('[BLE] StartScan error: $e');
    } finally {
      _scanStartInProgress = false;
    }
  }

  service.on('pauseScan').listen((_) async {
    _isScanPausedByUi = true;
    try {
      await FlutterBluePlus.stopScan();
      debugPrint('[BLE Service] Scan paused by UI to prevent OOM');
    } catch (_) {}
  });

  service.on('resumeScan').listen((_) {
    _isScanPausedByUi = false;
    debugPrint('[BLE Service] Scan resumed by UI');
    if (_isBluetoothOn) _runScan();
  });

  _adapterSub = FlutterBluePlus.adapterState.listen((state) async {
    if (state == BluetoothAdapterState.on) {
      _isBluetoothOn = true;
      _bluetoothAdapterJustTurnedOff = false; // Adapter is back ON — reset flag
      final resumedAt = DateTime.now();
      for (final beacon in _punchedIn) {
        _beaconLastSeen.putIfAbsent(beacon, () => resumedAt);
      }
      debugPrint('[BLE] Bluetooth is ON; ensuring scan is running');
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '📡 ResourcePlus Active',
          content: 'Scanning for office beacon...',
        );
      }
      _runScan();
      // Bluetooth can report ON before Android's scanner is ready. Retry only
      // when FlutterBluePlus reports that scanning is no longer active.
      _periodicScanTimer?.cancel();
      _periodicScanTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (_isBluetoothOn && !FlutterBluePlus.isScanningNow) {
          debugPrint('[BLE] Scanner inactive while Bluetooth is ON; retrying');
          _runScan();
        }
      });
    } else {
      _isBluetoothOn = false;
      _periodicScanTimer?.cancel();
      _periodicScanTimer = null;
      // FIX: Mark that the adapter itself turned OFF (user disabled Bluetooth).
      // The grace period timer must NOT punch OUT in this case — it is NOT the same
      // as physically leaving the beacon's range.
      _bluetoothAdapterJustTurnedOff = true;
      // Clear all beacon tracking so the timer does not fire punch OUTs
      _beaconLastSeen.clear();
      _detectedBeacons.clear();
      _rssiBuffer.clear();
      service.invoke('beaconUpdate', {'beacons': <Map<String, dynamic>>[]});
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '📡 ResourcePlus Paused',
          content: 'Bluetooth is OFF. Scanning paused.',
        );
      }
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        debugPrint('[BLE] StopScan error while Bluetooth is OFF: $e');
      }
    }
  });

  // ── Process scan results ─────────────────────────────────────────────────
  _scanSub = FlutterBluePlus.scanResults.listen((results) async {
    if (!_isBluetoothOn) return;
    final now = DateTime.now();
    _lastAnyScanResult = now;

    for (final result in results) {
      // Ignore stale cached results emitted by Android's continuous scanner
      if (now.difference(result.timeStamp).inSeconds > 10) continue;

      String name = result.device.platformName.trim().isNotEmpty
          ? result.device.platformName.trim()
          : result.advertisementData.advName.trim();

      String extractedUuid = '';

      // Parse iBeacon manufacturer data (Apple = 76 / 0x004C)
      if (result.advertisementData.manufacturerData.containsKey(76)) {
        final data = result.advertisementData.manufacturerData[76]!;
        // iBeacon packet structure: 02 15 [16 byte UUID] [2 byte Major] [2 byte Minor] [1 byte TX Power]
        if (data.length >= 23 && data[0] == 0x02 && data[1] == 0x15) {
          final uuidBytes = data.sublist(2, 18);
          extractedUuid = uuidBytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join('');
          // If the beacon didn't have a name, use its raw UUID as the identifier
          if (name.isEmpty) {
            name = extractedUuid;
          }
        }
      }

      if (name.isEmpty && extractedUuid.isEmpty)
        continue; // Skip pure noise (nameless and non-iBeacon)

      final mac = result.device.remoteId.str;

      // Try to match against authorized beacons to get the REAL name (e.g. DEMO-OFFICE-001)
      final cleanMacForMatch = mac
          .replaceAll(':', '')
          .replaceAll('-', '')
          .toLowerCase();
      final cleanNameForMatch = name.replaceAll('-', '').toLowerCase();
      final cleanExtractedUuid = extractedUuid
          .replaceAll('-', '')
          .toLowerCase();

      bool isAuthorized = false;
      String site = '';
      String zone = '';
      for (final b in BluetoothAttendanceConfig.authorizedBeacons) {
        final cleanUuid = b.uuid.replaceAll('-', '').toLowerCase();
        final cleanBeaconId = b.beaconId.replaceAll('-', '').toLowerCase();

        if (cleanBeaconId == cleanNameForMatch ||
            cleanUuid == cleanMacForMatch ||
            cleanUuid == cleanExtractedUuid ||
            cleanUuid == cleanNameForMatch) {
          name = b.beaconId; // USE THE OFFICIAL NAME!
          site = b.site;
          zone = b.zone;
          isAuthorized = true;
          break;
        }
      }

      // FIX: Only show AUTHORIZED beacons in the UI and tracking maps.
      // Unauthorized devices (like "Sreelakshmi's iPhone") must be completely
      // ignored — they clutter the beacon list and can cause false punches.
      if (!isAuthorized) continue;

      // CRITICAL FIX: Apple/Android beacon simulators rotate their hardware MAC address for privacy.
      // To prevent "seeing two of the same beacon", we MUST group authorized beacons by their
      // logical Beacon ID instead of their physical MAC address!
      final trackingKey = name; // Always use official beacon name as the key
      final previousSeen = _beaconLastSeen[trackingKey];
      if (previousSeen != null && !result.timeStamp.isAfter(previousSeen))
        continue;

      _detectedBeacons[trackingKey] = {
        'name': name,
        'macAddress': trackingKey, // The UI expects this to be unique per row
        'rssi': result.rssi,
        'site': site,
        'zone': zone,
        'lastSeen': result.timeStamp.toIso8601String(),
      };
      _beaconLastSeen[trackingKey] = result.timeStamp;

      _rssiBuffer.putIfAbsent(trackingKey, () => []);
      _rssiBuffer[trackingKey]!.add(result.rssi);
      if (_rssiBuffer[trackingKey]!.length > 5)
        _rssiBuffer[trackingKey]!.removeAt(0); // Keep last 5 samples
    }

    // ── Throttle the platform channel spam to prevent Android NativeAlloc OOM ──
    final int nowMs = now.millisecondsSinceEpoch;

    // Update the UI quickly (every 500ms) so it doesn't feel laggy
    if (nowMs - _lastUiUpdate > 1000) {
      _lastUiUpdate = nowMs;
      if (_detectedBeacons.isNotEmpty) {
        service.invoke('beaconUpdate', {
          'beacons': _detectedBeacons.values.toList(),
        });
      }
    }

    // Run the heavier auto-punch logic less frequently (every 2.5 seconds) to save battery and memory
    if (nowMs - _lastPunchProcess > 2500) {
      _lastPunchProcess = nowMs;
      _processPunches(_detectedBeacons);
    }
  });

  // ── Grace period timer: check for Punch OUT ───────────────────────────────
  _outTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
    if (_outCheckInProgress ||
        !_isBluetoothOn ||
        _bluetoothAdapterJustTurnedOff)
      return;
    _outCheckInProgress = true;
    try {
      final now = DateTime.now();

      // Android silently kills unfiltered background scans after ~30 mins.
      // Detect this by checking if FlutterBluePlus thinks it is scanning BUT
      // we haven't received any packets in over 90 seconds — the scan is dead.
      final scanAppearsAlive = FlutterBluePlus.isScanningNow;
      final noPacketsTooLong =
          now.difference(_lastAnyScanResult) > const Duration(seconds: 90);
      if (_isBluetoothOn && !_scanStartInProgress &&
          (!scanAppearsAlive || noPacketsTooLong)) {
        debugPrint(
          '[BLE] Scan dead (isScanningNow=$scanAppearsAlive, noPackets=$noPacketsTooLong). Restarting...',
        );
        _lastAnyScanResult = now; // reset to prevent spamming
        try {
          await FlutterBluePlus.stopScan();
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (_) {}
        _runScan();
        _outCheckInProgress = false;
        return;
      }

      final expired = <String>[];

      for (final entry in _beaconLastSeen.entries) {
        if (now.difference(entry.value) > gracePeriod) {
          expired.add(entry.key);
        }
      }

      if (expired.isNotEmpty) {
        final deviceId = await _getDeviceId();
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (_) {}

        for (final mac in expired) {
          if (_pendingIn.contains(mac)) continue;
          final lastSeen = _beaconLastSeen[mac];
          if (!_isBluetoothOn ||
              lastSeen == null ||
              DateTime.now().difference(lastSeen) <= gracePeriod)
            continue;
          // Get the exact moment the beacon was last seen before it expired
          final exactTimeLeft =
              _beaconLastSeen[mac] ?? DateTime.now().subtract(gracePeriod);

          // Keep lastSeen until OUT succeeds so cooldowns and failures retry.
          _notifiedBeacons.remove(mac);
          _rssiBuffer.remove(mac);
          _detectedBeacons.remove(mac);

          // Remove the "New Beacon Detected" notification
          flutterLocalNotificationsPlugin.cancel(mac.hashCode);

          final currentPunchedIn = List<String>.from(
            storage.read('punched_in_beacons') ?? [],
          );

          if (currentPunchedIn.contains(mac)) {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final lastPunch = storage.read('last_api_punch_$mac') ?? 0;

            // GLOBAL DEBOUNCE: strictly prevent ANY punch (IN or OUT) within 60 seconds of a previous one
            if (nowMs - lastPunch < 60000) continue;
            storage.write('last_api_punch_$mac', nowMs);

            final employeeName = storage.read('employeeName') ?? 'Employee';

            final utcStr = DateFormat(
              'MM/dd/yyyy HH:mm:ss',
            ).format(exactTimeLeft.toUtc());
            final localStr = DateFormat(
              'MM/dd/yyyy HH:mm:ss',
            ).format(exactTimeLeft);
            final off = now.timeZoneOffset;
            final tz =
                '${off.inHours >= 0 ? '+' : ''}${off.inHours.toString().padLeft(2, '0')}:${off.inMinutes.remainder(60).toString().padLeft(2, '0')}';
            final deviceinfo =
                '$deviceId|Bluetooth Mobile|$utcStr|$localStr|$tz';
            final lat = position?.latitude.toStringAsFixed(6) ?? '0.000000';
            final lng = position?.longitude.toStringAsFixed(6) ?? '0.000000';
            final locationinfo = '$lat|$lng| Address : BLE Beacon $mac,';
            final userName2 = (storage.read('username') ?? '').toString();
            final email2 = (storage.read('email') ?? '').toString();
            final usrEmail = userName2.isNotEmpty ? userName2 : email2;
            final instanceName = (storage.read('instanceName') ?? '')
                .toString();
            debugPrint(
              '[BLE OUT] usrEmail=$usrEmail instanceName=$instanceName',
            );

            try {
              final uri = Uri.parse(ApiEndpoints.markAttendancev2);
              final request = http.MultipartRequest('POST', uri);
              request.fields['usrEmail'] = usrEmail;
              request.fields['instanceName'] = instanceName;
              request.fields['checktype'] = '1'; // '1' = Punch OUT
              request.fields['Devicename'] = 'Bluetooth Mobile';
              request.fields['deviceinfo'] = deviceinfo;
              request.fields['locationinfo'] = locationinfo;
              request.fields['Lang'] =
                  (storage.read('currentLangCode') ??
                          storage.read('langCode') ??
                          '1')
                      .toString();
              // punchimage intentionally omitted — same as fingerprint punch pattern

              final ioClient = HttpClient()
                ..badCertificateCallback = (_, __, ___) => true;
              final client = io_client.IOClient(ioClient);
              late http.Response resp;
              try {
                resp = await client
                    .send(request)
                    .then(http.Response.fromStream)
                    .timeout(const Duration(seconds: 30));
              } finally {
                client.close();
              }

              final body = resp.body;
              final ok = attendanceAccepted(resp.statusCode, body);

              if (ok) {
                final updatedPunchedIn = List<String>.from(
                  storage.read('punched_in_beacons') ?? [],
                );
                updatedPunchedIn.remove(mac);
                storage.write('punched_in_beacons', updatedPunchedIn);
                _punchedIn.remove(mac);
                if (_beaconLastSeen[mac] == exactTimeLeft) {
                  _beaconLastSeen.remove(mac);
                }

                // Punch OUT notification — unique ID per event so each OUT shows separately
                try {
                  final hasPerm = await Permission.notification.isGranted;
                  if (hasPerm) {
                    final notifId =
                        DateTime.now().millisecondsSinceEpoch % 100000;
                    flutterLocalNotificationsPlugin.show(
                      notifId,
                      '🔴 Attendance: OUT — $employeeName',
                      'Left beacon range. API recorded check-out.',
                      const NotificationDetails(
                        android: AndroidNotificationDetails(
                          'bluetooth_attendance_channel',
                          'Bluetooth Attendance Tracking',
                          icon: '@mipmap/launcher_icon',
                          importance: Importance.high,
                          priority: Priority.high,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('[BLE Punch Out] Failed to show notification: $e');
                }

                // Notify Flutter UI of punch OUT
                service.invoke('punchEvent', {
                  'type': 'PUNCH_OUT',
                  'beaconMac': mac,
                  'employeeName': employeeName,
                  'timestamp': DateTime.now().toIso8601String(),
                });

                // Store in common local history
                final localRepo = MockLocalPunchRepository();
                localRepo.savePunch(
                  LocalPunchRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    timestamp: DateTime.now(),
                    checkType: 'O',
                    location: 'Office (Left Beacon Range)',
                    shiftDetails: 'Morning Shift',
                    punchMethod: 'Bluetooth',
                    deviceId: mac,
                    employeeName: employeeName,
                  ),
                );
              } else {
                print('API rejected check-out: $body');
              }
            } catch (e) {
              debugPrint('[BLE Punch OUT Error] $e');
            }
          } else {
            _beaconLastSeen.remove(mac);
          }
        }

        if (expired.isNotEmpty) {
          service.invoke('beaconUpdate', {
            'beacons': _detectedBeacons.values.toList(),
          });
        }
      }
    } catch (e) {
      debugPrint('[BLE OUT] Check failed; will retry: $e');
    } finally {
      _outCheckInProgress = false;
    }
  });
}
