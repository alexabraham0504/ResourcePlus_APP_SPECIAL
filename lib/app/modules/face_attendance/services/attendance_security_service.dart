import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../../services/device_info_helper.dart';
// uuid package v4.4.0 added — generates cryptographically secure UUIDs for RequestId

class AttendanceSecurityService {
  final _uuid = const Uuid();

  String generateRequestId() {
    return _uuid.v4();
  }

  Future<String> buildDeviceMetadata() async {
    final now = DateTime.now();
    final utcTime = DateFormat('MM/dd/yyyy HH:mm:ss').format(now.toUtc());
    final localTime = DateFormat('MM/dd/yyyy HH:mm:ss').format(now);
    
    final off = now.timeZoneOffset;
    final tz = '${off.inHours >= 0 ? '+' : ''}${off.inHours.toString().padLeft(2, '0')}'
        ':${off.inMinutes.remainder(60).toString().padLeft(2, '0')}';
        
    final deviceId = await DeviceInfoHelper.getPermanentDeviceId();
    return '$deviceId|Face Detection Mobile|$utcTime|$localTime|$tz';
  }

  Future<String> buildLocationMetadata() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return '0.000000|0.000000| Address : Location Disabled,';
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );
      
      final lat = position.latitude.toStringAsFixed(6);
      final lng = position.longitude.toStringAsFixed(6);
      return '$lat|$lng| Address : $lat/$lng,';
    } catch (e) {
      return '0.000000|0.000000| Address : Error fetching location,';
    }
  }
}
