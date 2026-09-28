import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../modules/bluetooth_attendance/services/background_tracking_service.dart';
import '../modules/home/controllers/home_controller.dart';

class GlobalBeaconController extends GetxController {
  StreamSubscription? _punchSubscription;
  StreamSubscription? _beaconSubscription;

  @override
  void onClose() {
    _punchSubscription?.cancel();
    _beaconSubscription?.cancel();
    super.onClose();
  }
  final Map<String, String> _lastRangeState = {};
  final Map<String, DateTime> _lastSeenMap = {};
  
  // Exposes the current nearest beacon color to the UI (App Bar)
  final Rx<Color?> activeBeaconColor = Rx<Color?>(null);
  
  // Exposes the current nearest beacon data for the popup
  final Rx<Map<String, dynamic>?> activeBeaconData = Rx<Map<String, dynamic>?>(null);

  @override
  void onInit() {
    super.onInit();
    _listenToDetectedBeacons();
    _listenToPunchEvents();
  }

  void _listenToPunchEvents() {
    final bgService = BackgroundTrackingService();
    
    _punchSubscription = bgService.punchStream.listen((data) {
      if (data == null) return;
      
      final type = data['type'];
      final name = data['employeeName'] ?? 'Employee';
      final beaconName = data['beaconName'] ?? 'Beacon';
      
      if (type == 'PUNCH_IN') {
        Get.snackbar(
          '✅ Attendance: IN',
          '$name successfully punched in at $beaconName.',
          backgroundColor: Colors.green.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(12),
          icon: const Icon(Icons.login, color: Colors.white),
        );
      } else if (type == 'PUNCH_OUT') {
        Get.snackbar(
          '🔴 Attendance: OUT',
          '$name left beacon range. Checked out.',
          backgroundColor: Colors.red.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(12),
          icon: const Icon(Icons.logout, color: Colors.white),
        );
      }

      // Refresh Home Tab and Attendance Tab data so the UI reflects the new punch immediately
      if (Get.isRegistered<HomeController>()) {
        final homeCtrl = Get.find<HomeController>();
        homeCtrl.fetchHomeData(silent: true);
        homeCtrl.fetchAttendanceData(silent: true);
      }
    });
  }

  void _listenToDetectedBeacons() {
    final bgService = BackgroundTrackingService();
    
    _beaconSubscription = bgService.beaconStream.listen((data) {
      if (data == null) return;
      final beaconList = data['beacons'] as List<dynamic>? ?? [];
      
      int maxRssi = -100;
      Map<String, dynamic>? strongestBeacon;
      
      for (final b in beaconList) {
        final map = b as Map<String, dynamic>;
        final mac = (map['macAddress'] ?? '') as String;
        final rssiVal = (map['rssi'] ?? -100) as int;
        final beaconNameStr = (map['name'] ?? 'Unknown') as String;
        
        _lastSeenMap[mac] = DateTime.now();
        if (rssiVal > maxRssi) {
          maxRssi = rssiVal;
          strongestBeacon = map;
        }
        
        final currentRange = _rssiLabel(rssiVal);
        final prevRange = _lastRangeState[mac] ?? '';
        
        if (currentRange != prevRange) {
          final isNew = prevRange.isEmpty;
          
          if (isNew && !Get.isSnackbarOpen) {
            final color = _rssiColor(rssiVal);
            Get.snackbar(
              'Beacon Detected',
              '$beaconNameStr is ${currentRange.tr}',
              backgroundColor: color.withValues(alpha: 0.9),
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 3),
              margin: const EdgeInsets.all(12),
              icon: const Icon(Icons.bluetooth_connected, color: Colors.white),
            );
          }
          _lastRangeState[mac] = currentRange;
        }
      }
      
      // Update global UI state based on strongest beacon
      if (strongestBeacon != null && maxRssi > -100) {
        activeBeaconColor.value = _rssiColor(maxRssi);
        activeBeaconData.value = strongestBeacon;
      } else {
        activeBeaconColor.value = null; // No beacons detected
        activeBeaconData.value = null;
      }
      
      // Cleanup expired beacons (not seen for > 30s)
      final now = DateTime.now();
      _lastRangeState.removeWhere((mac, _) {
         final lastSeen = _lastSeenMap[mac] ?? DateTime.fromMillisecondsSinceEpoch(0);
         return now.difference(lastSeen).inSeconds > 30;
      });
      _lastSeenMap.removeWhere((mac, lastSeen) => now.difference(lastSeen).inSeconds > 30);
      
      if (_lastSeenMap.isEmpty) {
        activeBeaconColor.value = null;
        activeBeaconData.value = null;
      }
    });
  }

  void showBeaconDetails() {
    final data = activeBeaconData.value;
    if (data == null) return;

    final name = data['name'] ?? 'Unknown Beacon';
    final site = data['site'] ?? 'N/A';
    final zone = data['zone'] ?? 'N/A';
    final rssi = data['rssi'] ?? -100;
    final range = _rssiLabel(rssi).tr;
    final color = _rssiColor(rssi);

    final isDark = Get.isDarkMode;

    Get.dialog(
      Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.2)),
            ),
          ),
          // Dialog content
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: Get.width * 0.85,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Gradient Header with Icon
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.8),
                            color.withValues(alpha: 0.4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ]
                            ),
                            child: const Icon(Icons.bluetooth_connected, size: 48, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Active Beacon',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Details Section
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildPremiumDetailRow('Name', name, Icons.badge_outlined, isDark),
                          const SizedBox(height: 16),
                          _buildPremiumDetailRow('Site', site, Icons.business_outlined, isDark),
                          const SizedBox(height: 16),
                          _buildPremiumDetailRow('Zone', zone, Icons.place_outlined, isDark),
                          const SizedBox(height: 16),
                          _buildPremiumDetailRow('Signal', '$rssi dBm ($range)', Icons.wifi_tethering, isDark, valueColor: color),
                          
                          const SizedBox(height: 32),
                          
                          // Custom Close Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF2C2C3E) : const Color(0xFFF0F4F8),
                                foregroundColor: isDark ? Colors.white : const Color(0xFF004A77),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => Get.back(),
                              child: Text(
                                'Close', 
                                style: GoogleFonts.outfit(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: true,
      barrierColor: Colors.transparent, // Using BackdropFilter instead
    );
  }

  Widget _buildPremiumDetailRow(String label, String value, IconData icon, bool isDark, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14, 
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: valueColor ?? (isDark ? Colors.white : const Color(0xFF1A1C1E)),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _rssiLabel(int rssi) {
    if (rssi >= -60) return 'very_close';
    if (rssi >= -75) return 'near';
    return 'far';
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -60) return Colors.green;
    if (rssi >= -75) return Colors.orange;
    return Colors.red;
  }
}
