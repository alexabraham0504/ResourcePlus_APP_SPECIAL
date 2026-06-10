import 'package:flutter/services.dart';

class SipServiceManager {
  static const MethodChannel _channel = MethodChannel(
    'com.resourceplus.app/sip_service',
  );

  /// Start the SIP service for camera, microphone, and location access
  static Future<bool> startService() async {
    try {
      final bool result = await _channel.invokeMethod('startService');
      print('🔧 SIP Service started: $result');
      return result;
    } catch (e) {
      print('❌ Error starting SIP Service: $e');
      return false;
    }
  }

  /// Stop the SIP service
  static Future<bool> stopService() async {
    try {
      final bool result = await _channel.invokeMethod('stopService');
      print('🔧 SIP Service stopped: $result');
      return result;
    } catch (e) {
      print('❌ Error stopping SIP Service: $e');
      return false;
    }
  }

  /// Check if the service is running
  static Future<bool> isServiceRunning() async {
    try {
      final bool result = await _channel.invokeMethod('isServiceRunning');
      print('🔧 SIP Service running: $result');
      return result;
    } catch (e) {
      print('❌ Error checking SIP Service status: $e');
      return false;
    }
  }
}

