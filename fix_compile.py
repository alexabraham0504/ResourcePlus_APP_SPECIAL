"""
Fix compile error: remove duplicate Permission block from bluetooth_punch_view.dart
Also apply Fix 3: remove scanGuard.invalidate() from resumeScan in service.
Run: python fix_compile.py
"""

# ─── Fix A: Remove duplicate Permission block from view ──────────────────────
view_path = r'lib\app\modules\bluetooth_attendance\views\bluetooth_punch_view.dart'
with open(view_path, 'rb') as f:
    view = f.read().decode('utf-8', errors='replace')

# The block was inserted with \n endings — find and remove it
REMOVE_BLOCK = (
    '    // SAMSUNG FIX: Request battery-optimization exemption when user opens\n'
    '    // the Bluetooth attendance screen. Samsung One UI kills background BLE\n'
    '    // scans after ~3 min on apps that are NOT battery-exempt. This is the\n'
    '    // sole reason attendance works on the developer phone (auto-exempted from\n'
    '    // weeks of use) but fails on fresh installs on Samsung Galaxy devices.\n'
    '    if (Platform.isAndroid) {\n'
    '      Permission.ignoreBatteryOptimizations.isGranted.then((granted) {\n'
    '        if (!granted) Permission.ignoreBatteryOptimizations.request();\n'
    '      });\n'
    '    }\n'
    '\n'
)
if REMOVE_BLOCK in view:
    view = view.replace(REMOVE_BLOCK, '', 1)
    print('Fix A: Removed duplicate Permission block from view')
elif 'Permission.ignoreBatteryOptimizations' in view:
    # Try to find and remove with regex
    import re
    view = re.sub(
        r'    // SAMSUNG FIX.*?Permission\.ignoreBatteryOptimizations\.request\(\);\s*\}\)\s*;\s*\}\s*\n\s*\n',
        '',
        view,
        flags=re.DOTALL
    )
    if 'Permission.ignoreBatteryOptimizations' not in view:
        print('Fix A: Removed via regex')
    else:
        print('Fix A ERROR: Could not remove block. Remove lines 279-288 manually in bluetooth_punch_view.dart')
else:
    print('Fix A: Nothing to remove')

with open(view_path, 'wb') as f:
    f.write(view.encode('utf-8'))

# ─── Fix B: Remove scanGuard.invalidate() from resumeScan ────────────────────
svc_path = r'lib\app\modules\bluetooth_attendance\services\background_tracking_service.dart'
with open(svc_path, 'rb') as f:
    raw = f.read()

# Work with raw bytes to handle mixed endings
svc = raw.decode('utf-8', errors='replace')

idx = svc.find("Scan resumed by UI'")
if idx == -1:
    print('Fix B ERROR: Could not find resumeScan in service file')
else:
    # Find scanGuard.invalidate() before the debugPrint
    region = svc[max(0,idx-150):idx+50]
    print('Fix B: Context around resumeScan:')
    print(repr(region))
    
    # Replace in the entire file using a broad search
    import re
    # Match scanGuard.invalidate() that is followed within a few lines by "Scan resumed"
    pattern = r'(scanGuard\.invalidate\(\);[\r\n]+)([ \t]*debugPrint\(\'?\[BLE Service\] Scan resumed by UI\'?\))'
    replacement = r'// Guard was reset when camera opened — do NOT invalidate on resume.\n\2'
    new_svc, n = re.subn(pattern, replacement, svc)
    if n > 0:
        svc = new_svc
        print(f'Fix B: Removed scanGuard.invalidate() from resumeScan ({n} replacement)')
    else:
        print('Fix B: Pattern not matched by regex either — may already be fixed')

with open(svc_path, 'wb') as f:
    f.write(svc.encode('utf-8'))

print('\n✅ Done. Now run: flutter build apk --release')
