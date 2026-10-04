"""
Fix: Remove permission check from _runScan() background isolate.
Run: python fix_runscan.py
"""
import re

svc_path = r'lib\app\modules\bluetooth_attendance\services\background_tracking_service.dart'
with open(svc_path, 'rb') as f:
    svc = f.read().decode('utf-8', errors='replace')

# Replace the entire _runScan function body
OLD = (
    '      if (Platform.isAndroid) {\r\n'
    '        final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;\r\n'
    '        final allowed = sdk >= 31\r\n'
    '            ? await Permission.bluetoothScan.isGranted &&\r\n'
    '                  await Permission.bluetoothConnect.isGranted\r\n'
    '            : await Permission.locationWhenInUse.isGranted;\r\n'
    '        if (!allowed || !await Geolocator.isLocationServiceEnabled()) {\r\n'
    '          debugPrint(\r\n'
    "            '[BLE] Scan paused: Bluetooth/location permission or Location service unavailable',\r\n"
    '          );\r\n'
    "          service.invoke('scanStatus', {'state': 'permission_required'});\r\n"
    '          return false;\r\n'
    '        }\r\n'
    '      }\r\n'
    '      await FlutterBluePlus.startScan(\r\n'
    '        // Match iBeacon frames at OS level for screen-off scanning.\r\n'
)
NEW = (
    '      // Do NOT add Permission.isGranted checks here.\r\n'
    '      // This runs in the background isolate where Permission context is\r\n'
    '      // unreliable — it can return false even when granted, silently\r\n'
    '      // blocking ALL scanning. Permissions are handled in the main isolate\r\n'
    '      // by BleCompatibilityCheck and initializeService().\r\n'
    '      await FlutterBluePlus.startScan(\r\n'
    '        // OS-level iBeacon filter (Apple=76, type=0x02, len=0x15).\r\n'
)

if OLD in svc:
    svc = svc.replace(OLD, NEW, 1)
    print('Fix: Removed permission check from _runScan()')
else:
    # Try unix line endings
    OLD_U = OLD.replace('\r\n', '\n')
    NEW_U = NEW.replace('\r\n', '\n')
    if OLD_U in svc:
        svc = svc.replace(OLD_U, NEW_U, 1)
        print('Fix: Removed permission check from _runScan() (unix endings)')
    else:
        print('ERROR: Pattern not found. Trying regex...')
        pattern = r'if \(Platform\.isAndroid\) \{.*?service\.invoke\(\'scanStatus\'.*?\}\r?\n      \}\r?\n'
        new_svc, n = re.subn(pattern, '      // Permission checks removed — unreliable in background isolate.\n', svc, flags=re.DOTALL)
        if n > 0:
            svc = new_svc
            print(f'Fix: Removed via regex ({n} match)')
        else:
            print('FAILED: Could not remove permission check. Manual edit needed.')
            print('  Open background_tracking_service.dart ~line 581-593 and delete the if(Platform.isAndroid) block.')

with open(svc_path, 'wb') as f:
    f.write(svc.encode('utf-8'))

print('\nDone. Run: flutter build apk --release && flutter install')
