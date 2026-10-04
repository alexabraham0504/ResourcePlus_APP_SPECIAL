"""
CRITICAL FIXES:
1. Fix race condition: credentials pushed to background service before listener ready → beacons load as empty
2. Fix OUT-on-app-BT-off: when app BT turns off, mark OUT after grace period
Run: python fix_core.py
"""
import re

SVC_PATH = r'lib\app\modules\bluetooth_attendance\services\background_tracking_service.dart'
VIEW_PATH = r'lib\app\modules\bluetooth_attendance\views\bluetooth_punch_view.dart'

# ─── Service fixes ──────────────────────────────────────────────────────────────
with open(SVC_PATH, 'rb') as f:
    svc = f.read().decode('utf-8', errors='replace')

# ── Fix A: BT-off should trigger grace-period OUT (not block it) ───────────────
# Find the _bluetoothAdapterJustTurnedOff = true line and change to false,
# and also stop clearing _beaconLastSeen (clearing it prevents the OUT timer)
OLD_A1 = '_bluetoothAdapterJustTurnedOff = true;\r\n'
NEW_A1 = '// _bluetoothAdapterJustTurnedOff kept false: BT off = treat like beacon out of range\r\n      _bluetoothAdapterJustTurnedOff = false;\r\n'
OLD_A1_U = '_bluetoothAdapterJustTurnedOff = true;\n'
NEW_A1_U = '// _bluetoothAdapterJustTurnedOff kept false: BT off = treat like beacon out of range\r\n      _bluetoothAdapterJustTurnedOff = false;\n'

# Only replace the one in the BT-off else branch (not any others)
if OLD_A1 in svc:
    # Make sure only replace the one after _beaconLastSeen.clear
    idx = svc.find('_isBluetoothOn = false;\r\n')
    if idx != -1:
        region = svc[idx:idx+600]
        if '_bluetoothAdapterJustTurnedOff = true;' in region:
            new_region = region.replace('_bluetoothAdapterJustTurnedOff = true;\r\n', 
                                        '_bluetoothAdapterJustTurnedOff = false; // BT-off = grace period OUT\r\n', 1)
            svc = svc[:idx] + new_region + svc[idx+600:]
            print('Fix A: BT-off now triggers grace period OUT')
        else:
            print('Fix A: Could not find in expected location')
    else:
        print('Fix A: _isBluetoothOn = false not found')
elif '_bluetoothAdapterJustTurnedOff = false; // BT-off = grace period OUT' in svc:
    print('Fix A: Already applied')
else:
    print('Fix A: Could not find pattern')

# ── Fix B: Do NOT clear _beaconLastSeen when BT turns off ─────────────────────
# _beaconLastSeen.clear() wipes the departure timestamps so OUT timer can't fire
OLD_B1 = '      _beaconLastSeen.clear();\r\n      _detectedBeacons.clear();\r\n      _rssiBuffer.clear();\r\n'
NEW_B1 = ('      // Do NOT clear _beaconLastSeen when BT goes off — the departure\r\n'
           '      // grace period timer uses these timestamps to decide when to punch OUT.\r\n'
           '      _detectedBeacons.clear();\r\n'
           '      _rssiBuffer.clear();\r\n')
OLD_B1_U = '      _beaconLastSeen.clear();\n      _detectedBeacons.clear();\n      _rssiBuffer.clear();\n'
NEW_B1_U = ('      // Do NOT clear _beaconLastSeen when BT goes off.\n'
             '      _detectedBeacons.clear();\n'
             '      _rssiBuffer.clear();\n')

if OLD_B1 in svc:
    svc = svc.replace(OLD_B1, NEW_B1, 1)
    print('Fix B: _beaconLastSeen preserved on BT-off (grace period OUT will now fire)')
elif OLD_B1_U in svc:
    svc = svc.replace(OLD_B1_U, NEW_B1_U, 1)
    print('Fix B: Applied (unix endings)')
elif '_beaconLastSeen.clear()' not in svc:
    print('Fix B: Already applied or _beaconLastSeen.clear not found')
else:
    print('Fix B: Could not match exactly — manual edit needed')

with open(SVC_PATH, 'wb') as f:
    f.write(svc.encode('utf-8'))
    print('Service file written')

# ─── View fix: push credentials AFTER service listener is ready ───────────────
with open(VIEW_PATH, 'rb') as f:
    view = f.read().decode('utf-8', errors='replace')

# The race condition: UI pushes credentials before bg isolate registers its listener.
# Fix: delay the credential push by 600ms so the listener is ready.
if '_pushCredentialsToBackgroundService();\r\n\r\n    _checkServiceStatus();' in view:
    view = view.replace(
        '_pushCredentialsToBackgroundService();\r\n\r\n    _checkServiceStatus();',
        '''// Push credentials AFTER service starts to avoid race condition where
    // the background isolate hasn't registered updateCredentials listener yet.
    _checkServiceStatus();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _pushCredentialsToBackgroundService();
    });''',
        1
    )
    print('Fix C: Credentials delayed until service listener is ready')
elif '_pushCredentialsToBackgroundService();\n\n    _checkServiceStatus();' in view:
    view = view.replace(
        '_pushCredentialsToBackgroundService();\n\n    _checkServiceStatus();',
        '''// Push credentials AFTER service starts (race condition fix).
    _checkServiceStatus();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _pushCredentialsToBackgroundService();
    });''',
        1
    )
    print('Fix C: Applied (unix endings)')
elif 'Push credentials AFTER service starts' in view:
    print('Fix C: Already applied')
else:
    print('Fix C: Pattern not found. Manual edit needed.')

with open(VIEW_PATH, 'wb') as f:
    f.write(view.encode('utf-8'))
    print('View file written')

print('\nAll fixes done. Run: flutter build apk --release && flutter install')
