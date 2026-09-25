import 'package:get_storage/get_storage.dart';
import '../models/registered_device.dart';

class HostDeviceRegistry {
  static final _storage = GetStorage();
  static const _registryKey = 'host_device_registry_v2'; // Switched to v2 to invalidate old name-based registries

  /// Maps Bluetooth Device Identifier (remoteId) to RegisteredDevice
  static Map<String, RegisteredDevice> getRegisteredDevices() {
    final Map<String, dynamic>? data = _storage.read<Map<String, dynamic>>(_registryKey);
    if (data == null) return {};
    
    return data.map((key, value) {
      return MapEntry(key, RegisteredDevice.fromJson(Map<String, dynamic>.from(value)));
    });
  }

  /// Registers a new employee device using the strict deviceIdentifier (remoteId)
  static Future<void> registerDevice(RegisteredDevice device) async {
    final current = getRegisteredDevices();
    
    // Prevent duplicate device identifiers
    current[device.deviceIdentifier] = device;
    
    // Store as JSON
    final jsonMap = current.map((key, value) => MapEntry(key, value.toJson()));
    await _storage.write(_registryKey, jsonMap);
  }

  /// Removes a registered device by identifier
  static Future<void> unregisterDevice(String deviceIdentifier) async {
    final current = getRegisteredDevices();
    current.remove(deviceIdentifier);
    
    final jsonMap = current.map((key, value) => MapEntry(key, value.toJson()));
    await _storage.write(_registryKey, jsonMap);
  }
}
