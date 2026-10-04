"""
Add pre-consent dialog for battery optimization and remove duplicate requests.
Run: python fix_consent.py
"""

# ─── 1. Remove duplicate from background_tracking_service.dart ───────────────
svc_path = r'lib\app\modules\bluetooth_attendance\services\background_tracking_service.dart'
with open(svc_path, 'rb') as f:
    svc = f.read().decode('utf-8', errors='replace')

import re
pattern = r'[ \t]*// SAMSUNG FIX: Prevents One UI from killing the background BLE scan\.[\r\n]+[ \t]*if \(!\(await Permission\.ignoreBatteryOptimizations\.isGranted\)\) \{[\r\n]+[ \t]*await Permission\.ignoreBatteryOptimizations\.request\(\);[\r\n]+[ \t]*\}[\r\n]+'
new_svc, n = re.subn(pattern, '', svc)
if n > 0:
    print(f'Service: Removed duplicate battery request ({n})')
    with open(svc_path, 'wb') as f:
        f.write(new_svc.encode('utf-8'))
else:
    print('Service: Could not find duplicate battery request. It may be already removed.')

# ─── 2. Update BleCompatibilityCheck with Consent Dialog ──────────────────────
util_path = r'lib\app\modules\bluetooth_attendance\utils\ble_compatibility_check.dart'
with open(util_path, 'rb') as f:
    util = f.read().decode('utf-8', errors='replace')

# Look for the battery check block
start_marker = '    // 1. Battery Optimization'
end_marker = '    // 2. Location Permission'
start_idx = util.find(start_marker)
if start_idx == -1:
    print('ERROR: Could not find battery check block in util')
else:
    end_idx = util.find(end_marker, start_idx)
    
    CONSENT_BLOCK = '''    // 1. Battery Optimization
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
            'ResourcePlus needs to run in the background.\\n\\n'
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
            issues.add('Battery optimization is ON → App killed in background after ~3 min.\\n'
                'Go to: Settings → Battery → Background usage limits → Add ResourcePlus as "Never sleeping"');
          }
        } catch (_) {
          issues.add('Battery optimization exemption could not be requested automatically.');
        }
      } else {
        issues.add('Background permission denied. Auto-checkout will not work.');
      }
    }

'''
    new_util = util[:start_idx] + CONSENT_BLOCK + util[end_idx:]
    with open(util_path, 'wb') as f:
        f.write(new_util.encode('utf-8'))
    print('Util: Replaced battery logic with Pre-Consent Dialog')

print('\nDone. Run: flutter build apk --release')
