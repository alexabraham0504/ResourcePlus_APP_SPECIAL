import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/api_endpoints.dart';
import '../../../../services/api_service.dart';
import '../../../../controllers/language_controller.dart';

class ShiftLocationBlock extends StatefulWidget {
  final ColorScheme colorScheme;
  final bool isDark;

  const ShiftLocationBlock({
    super.key,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  State<ShiftLocationBlock> createState() => _ShiftLocationBlockState();
}

class _ShiftLocationBlockState extends State<ShiftLocationBlock> {
  String _currentShift = 'Loading...';
  String _currentCoordinates = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchShiftDetails();
    _getCurrentLocation();
  }

  Future<void> _fetchShiftDetails() async {
    try {
      final storage = GetStorage();
      final instanceName = storage.read('instanceName') ?? '';
      final userName = storage.read('username');
      final userEmail = storage.read('email');

      final usrEmailValue = (userName != null && userName.toString().isNotEmpty)
          ? userName.toString()
          : (userEmail != null && userEmail.toString().isNotEmpty)
              ? userEmail.toString()
              : null;

      if (usrEmailValue == null) {
        setState(() => _currentShift = 'User error');
        return;
      }

      final languageController = Get.find<LanguageController>();
      final dio = ApiService().dio;

      final response = await dio.get(
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
              cleanData = cleanData.substring(1, cleanData.length - 1).replaceAll('\\"', '"');
            }
            responseData = jsonDecode(cleanData);
          } catch (_) {}
        }
        
        List<dynamic>? shiftData;
        if (responseData is List) shiftData = responseData;
        else if (responseData is Map) {
          if (responseData.containsKey('data') && responseData['data'] is List) shiftData = responseData['data'];
          else if (responseData.containsKey('ShiftDetails') && responseData['ShiftDetails'] is List) shiftData = responseData['ShiftDetails'];
          else if (responseData.containsKey('Table') && responseData['Table'] is List) shiftData = responseData['Table'];
        }

        if (shiftData != null && shiftData.isNotEmpty) {
          final shiftInfo = shiftData[0];
          final shiftName = shiftInfo['ShiftName']?.toString() ?? shiftInfo['shift_name']?.toString() ?? shiftInfo['shiftname']?.toString();
          if (shiftName != null && shiftName.isNotEmpty) {
            setState(() => _currentShift = shiftName);
          } else {
            setState(() => _currentShift = 'No shift assigned');
          }
        } else {
          setState(() => _currentShift = 'No shift');
        }
      } else {
        setState(() => _currentShift = 'Server error');
      }
    } catch (e) {
      setState(() => _currentShift = 'Conn error');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _currentCoordinates = 'Location disabled');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _currentCoordinates = 'Permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _currentCoordinates = 'Permission denied forever');
        return;
      }

      // Quick fetch of last known position so UI shows something immediately
      try {
        Position? lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          setState(() {
            _currentCoordinates = '${lastPos.latitude.toStringAsFixed(6)}, ${lastPos.longitude.toStringAsFixed(6)}';
          });
        }
      } catch (_) {}

      // Get accurate current position (allow up to 15 seconds)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      if (mounted) {
        setState(() {
          _currentCoordinates = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        });
      }
    } catch (e) {
      // If accurate fetch times out, only show error if we haven't already got a last known position
      if (_currentCoordinates == 'Loading...' && mounted) {
        setState(() => _currentCoordinates = 'Location error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: widget.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.schedule_rounded, color: widget.colorScheme.primary, size: 18)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('current_shift'.tr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.grey[400] : Colors.grey[500])),
                    const SizedBox(height: 2),
                    Text(_currentShift, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : const Color(0xFF1E293B))),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: widget.colorScheme.outline.withValues(alpha: 0.1)),
          ),
          InkWell(
            onTap: () async {
               if (_currentCoordinates.contains(',')) {
                 final parts = _currentCoordinates.split(',');
                 final lat = parts[0].trim();
                 final lng = parts[1].trim();
                 final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                 try {
                   if (await canLaunchUrl(uri)) {
                     await launchUrl(uri);
                   }
                 } catch(e){}
               }
            },
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: widget.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.location_on_rounded, color: widget.colorScheme.primary, size: 18)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('location'.tr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.grey[400] : Colors.grey[500])),
                      const SizedBox(height: 2),
                      Text(_currentCoordinates, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: widget.isDark ? Colors.white : const Color(0xFF1E293B))),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded, size: 16, color: widget.colorScheme.primary.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
