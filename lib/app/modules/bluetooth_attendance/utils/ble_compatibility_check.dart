import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

/// Runs a full device compatibility check for Bluetooth attendance and shows
/// a single, actionable dialog if anything is wrong.
///
/// Call this from any screen that depends on background BLE scanning.
/// It handles Samsung, Xiaomi, Oppo, Vivo, OnePlus battery killers automatically.
///
/// Usage:
///   await BleCompatibilityCheck.run(context);
class BleCompatibilityCheck {
  BleCompatibilityCheck._();

  static Future<bool> run(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final issues = <String>[];

    // 1. Battery Optimization
    final batteryGranted = await Permission.ignoreBatteryOptimizations.isGranted;
    if (!batteryGranted && context.mounted) {
      // PRE-CONSENT DIALOG: Explain why we need this before the scary OS prompt
      final bool? proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.privacy_tip, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text('Background Scanning', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
          content: const Text(
            'To automatically clock you out when you leave the office, '
            'ResourcePlus needs to run in the background.\n\n'
            'On the next screen, please tap "Allow" so the app can continue '
            'scanning even when you lock your phone.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF)),
              child: const Text('Continue', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (proceed == true) {
        try {
          final result = await Permission.ignoreBatteryOptimizations.request();
          if (!result.isGranted) {
            issues.add('Battery optimization is ON → App killed in background after ~3 min.\n'
                'Go to: Settings → Battery → Background usage limits → Add ResourcePlus as "Never sleeping"');
          }
        } catch (_) {
          issues.add('Battery optimization exemption could not be requested automatically.');
        }
      } else {
        issues.add('Background permission denied. Auto-checkout will not work.');
      }
    }

    // 2. Location Permission (required for BLE scanning on Android)
    if (!(await Permission.locationWhenInUse.isGranted)) {
      final r = await Permission.locationWhenInUse.request();
      if (!r.isGranted) issues.add('Location permission denied → Bluetooth scan will not start.');
    }

    // 3. Background Location (required to scan while screen is off)
    if (!(await Permission.locationAlways.isGranted)) {
      final r = await Permission.locationAlways.request();
      if (!r.isGranted) {
        issues.add('Background location denied → Scan stops when screen turns off.\n'
            'Go to: Settings → Apps → ResourcePlus → Location → Allow all the time');
      }
    }

    // 4. Bluetooth Scan & Connect
    if (!(await Permission.bluetoothScan.isGranted)) {
      await Permission.bluetoothScan.request();
    }
    if (!(await Permission.bluetoothConnect.isGranted)) {
      await Permission.bluetoothConnect.request();
    }

    // 5. GPS must be ON
    if (!(await Geolocator.isLocationServiceEnabled())) {
      issues.add('Location (GPS) is OFF → Turn ON GPS for beacon detection to work.');
    }

    // 6. Show dialog if anything failed
    if (issues.isNotEmpty && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Action Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Complete these steps so Bluetooth attendance works on this phone:',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                ...issues.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('⚠️  ', style: TextStyle(fontSize: 13)),
                    Expanded(child: Text(i, style: const TextStyle(fontSize: 13))),
                  ]),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async { Navigator.of(context).pop(); await openAppSettings(); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF)),
              child: const Text('Open App Settings', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }
}
