"""
All remaining Bluetooth cross-device fixes. Run from the project root.
  python fix_samsung.py
"""
import re, os

# ─── Fix 1: Add import to bluetooth_punch_view.dart ───────────────────────
view_path = r'lib\app\modules\bluetooth_attendance\views\bluetooth_punch_view.dart'
with open(view_path, 'rb') as f:
    view = f.read().decode('utf-8', errors='replace')

IMPORT_MARKER = "import '../config/bluetooth_attendance_config.dart';"
COMPAT_IMPORT = "import '../utils/ble_compatibility_check.dart';"

if COMPAT_IMPORT not in view:
    view = view.replace(IMPORT_MARKER, IMPORT_MARKER + '\n' + COMPAT_IMPORT, 1)
    print('Fix 1: Added BleCompatibilityCheck import')
else:
    print('Fix 1: Already present')

# ─── Fix 2: Wire BleCompatibilityCheck.run in initState ───────────────────
INIT_OLD = "    _checkServiceStatus();\r\n    _listenToBackgroundService();\r\n    _listenToHardwareStates();\r\n  }"
INIT_NEW = (
    "    _checkServiceStatus();\r\n"
    "    _listenToBackgroundService();\r\n"
    "    _listenToHardwareStates();\r\n"
    "\r\n"
    "    // Run compatibility check after first frame. Requests battery\r\n"
    "    // optimization exemption on Samsung/Xiaomi/Oppo/Vivo/OnePlus so the\r\n"
    "    // background scanner is never killed by aggressive manufacturer Doze.\r\n"
    "    WidgetsBinding.instance.addPostFrameCallback((_) {\r\n"
    "      if (mounted) BleCompatibilityCheck.run(context);\r\n"
    "    });\r\n"
    "  }"
)
INIT_OLD_U = "    _checkServiceStatus();\n    _listenToBackgroundService();\n    _listenToHardwareStates();\n  }"
INIT_NEW_U = (
    "    _checkServiceStatus();\n"
    "    _listenToBackgroundService();\n"
    "    _listenToHardwareStates();\n"
    "\n"
    "    // Run compatibility check after first frame.\n"
    "    WidgetsBinding.instance.addPostFrameCallback((_) {\n"
    "      if (mounted) BleCompatibilityCheck.run(context);\n"
    "    });\n"
    "  }"
)

if 'BleCompatibilityCheck.run' not in view:
    if INIT_OLD in view:
        view = view.replace(INIT_OLD, INIT_NEW, 1)
        print('Fix 2: Wired BleCompatibilityCheck.run into initState')
    elif INIT_OLD_U in view:
        view = view.replace(INIT_OLD_U, INIT_NEW_U, 1)
        print('Fix 2: Wired BleCompatibilityCheck.run into initState (unix)')
    else:
        print('Fix 2 ERROR: initState pattern not found. Searching...')
        idx = view.find('_listenToHardwareStates()')
        if idx >= 0:
            print('  Found _listenToHardwareStates at index', idx)
            print(repr(view[idx:idx+100]))
else:
    print('Fix 2: Already present')

with open(view_path, 'wb') as f:
    f.write(view.encode('utf-8'))

# ─── Fix 3: Remove scanGuard.invalidate() from resumeScan in service ──────
svc_path = r'lib\app\modules\bluetooth_attendance\services\background_tracking_service.dart'
with open(svc_path, 'rb') as f:
    svc = f.read().decode('utf-8', errors='replace')

# Try to find and replace the invalidate() line in resumeScan context
patterns = [
    ("    scanGuard.invalidate();\r\n    debugPrint('[BLE Service] Scan resumed by UI');\r\n",
     "    // Guard was already reset when camera opened — do NOT invalidate on resume.\r\n    debugPrint('[BLE Service] Scan resumed by UI');\r\n"),
    ("    scanGuard.invalidate();\n    debugPrint('[BLE Service] Scan resumed by UI');\n",
     "    // Guard was already reset when camera opened — do NOT invalidate on resume.\n    debugPrint('[BLE Service] Scan resumed by UI');\n"),
]
fix3_done = False
for old, new in patterns:
    if old in svc:
        svc = svc.replace(old, new, 1)
        fix3_done = True
        print('Fix 3: Removed scanGuard.invalidate() from resumeScan')
        break
if not fix3_done:
    if 'resumed by UI' in svc and 'Guard was already reset' not in svc:
        print('Fix 3 ERROR: Pattern not found. Manual edit needed at line ~619.')
    else:
        print('Fix 3: Already fixed or not found (may already be correct)')

# ─── Fix 4: Add ignoreBatteryOptimizations.request() to initializeService ─
if 'ignoreBatteryOptimizations' not in svc:
    patterns4 = [
        ("      await Permission.bluetoothConnect.request();\r\n    }\r\n",
         "      await Permission.bluetoothConnect.request();\r\n"
         "      // SAMSUNG FIX: Prevent One UI from killing background BLE scan.\r\n"
         "      if (!(await Permission.ignoreBatteryOptimizations.isGranted)) {\r\n"
         "        await Permission.ignoreBatteryOptimizations.request();\r\n"
         "      }\r\n"
         "    }\r\n"),
        ("      await Permission.bluetoothConnect.request();\n    }\n",
         "      await Permission.bluetoothConnect.request();\n"
         "      // SAMSUNG FIX: Prevent One UI from killing background BLE scan.\n"
         "      if (!(await Permission.ignoreBatteryOptimizations.isGranted)) {\n"
         "        await Permission.ignoreBatteryOptimizations.request();\n"
         "      }\n"
         "    }\n"),
    ]
    fix4_done = False
    for old, new in patterns4:
        if old in svc:
            svc = svc.replace(old, new, 1)
            fix4_done = True
            print('Fix 4: Added ignoreBatteryOptimizations to initializeService')
            break
    if not fix4_done:
        print('Fix 4 ERROR: Could not find pattern for initializeService. Manual edit needed.')
else:
    print('Fix 4: ignoreBatteryOptimizations already in service file')

with open(svc_path, 'wb') as f:
    f.write(svc.encode('utf-8'))

print('\n✅ All fixes applied. Now run:')
print('   flutter build apk --release')
print('   flutter install')
