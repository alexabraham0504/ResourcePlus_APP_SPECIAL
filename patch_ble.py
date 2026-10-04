import re

path = r'lib\app\modules\bluetooth_attendance\services\background_tracking_service.dart'
with open(path, 'rb') as f:
    content = f.read()

# Decode with latin-1 to preserve raw bytes
text = content.decode('latin-1')

# Fix 1: Remove scanGuard.invalidate() from resumeScan listener
old = '    scanGuard.invalidate();\r\n    debugPrint(\'[BLE Service] Scan resumed by UI\');\r\n'
new = '    // Do NOT invalidate here — guard was reset when camera opened.\r\n    debugPrint(\'[BLE Service] Scan resumed by UI\');\r\n'
if old in text:
    text = text.replace(old, new, 1)
    print('Fix 1 applied: removed invalidate from resumeScan')
else:
    print('Fix 1 NOT FOUND — checking alternate endings')
    old2 = '    scanGuard.invalidate();\n    debugPrint(\'[BLE Service] Scan resumed by UI\');\n'
    if old2 in text:
        text = text.replace(old2, new.replace('\r\n', '\n'), 1)
        print('Fix 1 applied (unix endings)')
    else:
        print('ERROR: Could not find pattern for Fix 1')
        # Print surrounding context for debugging
        idx = text.find('resumeScan')
        if idx >= 0:
            print(repr(text[idx:idx+300]))

with open(path, 'wb') as f:
    f.write(text.encode('latin-1'))

print('Done.')
