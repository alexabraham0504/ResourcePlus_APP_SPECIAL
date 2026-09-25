// lib/app/modules/bluetooth_attendance/config/bluetooth_attendance_config.dart
//
// Live beacon list is fetched from the real API via BluetoothBeaconService.
// The static authorizedBeacons list below is used as a fallback when the
// API is unreachable (e.g. the device is offline when the service starts).

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import '../../../config/api_endpoints.dart';

enum MockScenario {
  demoSuccess,
  demoRejectedBeacon,
  demoWeakProximity,
  demoLocationFailed,
  demoDuplicate,
  demoNetworkError,
  demoReview,
}

class BluetoothAttendanceConfig {
  /// Set to `false` — we are now using real API for beacons + punch.
  static bool demoMode = false;

  /// The active mock scenario for testing without modifying UI code.
  static MockScenario activeScenario = MockScenario.demoSuccess;

  /// Live authorized beacon list — populated from server at service start.
  /// Falls back to [_fallbackBeacons] if the API call fails.
  static List<BleBeaconConfig> authorizedBeacons = List.unmodifiable(_fallbackBeacons);

  /// Refresh authorized beacons from the server.
  /// Call this once when the background service starts.
  static Future<void> refreshBeaconsFromApi() async {
    final storage = GetStorage();
    final instanceName = storage.read('instanceName') ?? '';
    final usrEmail = (storage.read('username') ?? storage.read('userEmail') ?? '').toString();

    if (instanceName.isEmpty || usrEmail.isEmpty) {
      debugPrint('[BLE Beacons] Missing credentials — using fallback beacons');
      return;
    }

    final ioClient = HttpClient()..badCertificateCallback = (_, __, ___) => true;
    final client = io_client.IOClient(ioClient);

    try {
      final uri = Uri.parse(ApiEndpoints.bluetoothBeacons).replace(
        queryParameters: {
          'instanceName': instanceName,
          'usrEmail': usrEmail,
        },
      );

      debugPrint('[BLE Beacons] Fetching from ${uri.toString()}');
      final response = await client.get(uri).timeout(const Duration(seconds: 15));
      debugPrint('[BLE Beacons] Response ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(response.body);
        if (raw.isNotEmpty) {
          final beacons = raw.map((b) {
            return BleBeaconConfig(
              beaconId: (b['beaconId'] ?? '').toString(),
              uuid: (b['uuid'] ?? '').toString().toLowerCase(),
              major: (b['major'] as num?)?.toInt() ?? 0,
              minor: (b['minor'] as num?)?.toInt() ?? 0,
              site: (b['site'] ?? '').toString(),
              zone: (b['zone'] ?? '').toString(),
            );
          }).toList();
          authorizedBeacons = List.unmodifiable(beacons);
          // Cache so the service can use them after a cold start without network
          storage.write('ble_authorized_beacons', jsonEncode(raw));
          debugPrint('[BLE Beacons] ✅ Loaded ${beacons.length} authorized beacons from server');
        } else {
          debugPrint('[BLE Beacons] ⚠️ Server returned empty beacon list');
          _loadCachedBeacons(storage);
        }
      } else {
        debugPrint('[BLE Beacons] ❌ Error ${response.statusCode} — loading cache');
        _loadCachedBeacons(storage);
      }
    } catch (e) {
      debugPrint('[BLE Beacons] ❌ Network error: $e — loading cache');
      _loadCachedBeacons(storage);
    } finally {
      client.close();
    }
  }

  static void _loadCachedBeacons(GetStorage storage) {
    final cached = storage.read<String>('ble_authorized_beacons');
    if (cached != null) {
      try {
        final List<dynamic> raw = jsonDecode(cached);
        authorizedBeacons = List.unmodifiable(raw.map((b) => BleBeaconConfig(
          beaconId: (b['beaconId'] ?? '').toString(),
          uuid: (b['uuid'] ?? '').toString().toLowerCase(),
          major: (b['major'] as num?)?.toInt() ?? 0,
          minor: (b['minor'] as num?)?.toInt() ?? 0,
          site: (b['site'] ?? '').toString(),
          zone: (b['zone'] ?? '').toString(),
        )).toList());
        debugPrint('[BLE Beacons] ✅ Loaded ${authorizedBeacons.length} cached beacons');
      } catch (_) {
        debugPrint('[BLE Beacons] ⚠️ Cache parse failed — using hardcoded fallback');
      }
    }
  }

  /// Check if this device is already registered for a specific beacon.
  static Future<bool> checkRegistration(String deviceIdentifier, {String? beaconId}) async {
    final storage = GetStorage();
    final instanceName = storage.read('instanceName') ?? '';
    final usrEmail = (storage.read('username') ?? storage.read('userEmail') ?? '').toString();

    if (instanceName.isEmpty || usrEmail.isEmpty) return false;

    final ioClient = HttpClient()..badCertificateCallback = (_, __, ___) => true;
    final client = io_client.IOClient(ioClient);

    try {
      final queryParams = {
        'instanceName': instanceName,
        'usrEmail': usrEmail,
        'deviceIdentifier': deviceIdentifier,
      };
      if (beaconId != null && beaconId.isNotEmpty) {
        queryParams['beaconId'] = beaconId;
      }

      final uri = Uri.parse(ApiEndpoints.bluetoothCheckRegistration).replace(
        queryParameters: queryParams,
      );

      debugPrint('[BLE Check] Checking registration: $uri');
      final response = await client.get(uri).timeout(const Duration(seconds: 15));
      debugPrint('[BLE Check] Response ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['isRegistered'] == true) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[BLE Check] Error: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Register this device with the backend for a specific beacon.
  static Future<bool> registerDevice(String deviceIdentifier, {String? beaconId}) async {
    final storage = GetStorage();
    final instanceName = storage.read('instanceName') ?? '';
    final usrEmail = (storage.read('username') ?? storage.read('userEmail') ?? '').toString();

    if (instanceName.isEmpty || usrEmail.isEmpty) return false;

    final ioClient = HttpClient()..badCertificateCallback = (_, __, ___) => true;
    final client = io_client.IOClient(ioClient);

    try {
      final uri = Uri.parse(ApiEndpoints.bluetoothRegister).replace(
        queryParameters: {
          'instanceName': instanceName,
        },
      );

      final payload = {
        'usrEmail': usrEmail,
        'deviceIdentifier': deviceIdentifier,
      };
      if (beaconId != null && beaconId.isNotEmpty) {
        payload['beaconId'] = beaconId;
      }

      debugPrint('[BLE Register] Registering: $uri');
      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('[BLE Register] Response ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[BLE Register] Error: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Hardcoded fallback — used if both API and cache fail.
  static const List<BleBeaconConfig> _fallbackBeacons = [
    BleBeaconConfig(
      beaconId: 'DEMO-OFFICE-001',
      uuid: '11111111-1111-1111-1111-111111111111',
      major: 100,
      minor: 1,
      site: 'Demo Office',
      zone: 'Main Entrance',
    ),
    BleBeaconConfig(
      beaconId: 'iBeacon Profile',
      uuid: '11111111-1111-1111-1111-111111111111',
      major: 100,
      minor: 1,
      site: 'Demo Office',
      zone: 'Main Entrance',
    ),
  ];
}

class BleBeaconConfig {
  final String beaconId;
  final String uuid;
  final int major;
  final int minor;
  final String site;
  final String zone;

  const BleBeaconConfig({
    required this.beaconId,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.site,
    required this.zone,
  });
}
