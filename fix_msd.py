"""
Fix: Remove aggressive OS-level MSD filtering that breaks Samsung scanning.
Run: python fix_msd.py
"""
import re

svc_path = r'lib\app\modules\bluetooth_attendance\services\background_tracking_service.dart'
with open(svc_path, 'rb') as f:
    svc = f.read().decode('utf-8', errors='replace')

# We need to remove the withMsd filter block from startScan
OLD_BLOCK_1 = (
    '      await FlutterBluePlus.startScan(\r\n'
    '        // OS-level iBeacon filter (Apple=76, type=0x02, len=0x15).\r\n'
    '        continuousUpdates: true,\r\n'
    '        withMsd: [\r\n'
    '          MsdFilter(76, data: [2, 21]),\r\n'
    '        ],\r\n'
    '        removeIfGone: const Duration(seconds: 10),\r\n'
    '      );\r\n'
)

OLD_BLOCK_2 = (
    '      await FlutterBluePlus.startScan(\n'
    '        // OS-level iBeacon filter (Apple=76, type=0x02, len=0x15).\n'
    '        continuousUpdates: true,\n'
    '        withMsd: [\n'
    '          MsdFilter(76, data: [2, 21]),\n'
    '        ],\n'
    '        removeIfGone: const Duration(seconds: 10),\n'
    '      );\n'
)

NEW_BLOCK = (
    '      await FlutterBluePlus.startScan(\n'
    '        continuousUpdates: true,\n'
    '        removeIfGone: const Duration(seconds: 10),\n'
    '      );\n'
)

if OLD_BLOCK_1 in svc:
    svc = svc.replace(OLD_BLOCK_1, NEW_BLOCK.replace('\n', '\r\n'), 1)
    print('Fix: Removed MSD filter (windows endings)')
elif OLD_BLOCK_2 in svc:
    svc = svc.replace(OLD_BLOCK_2, NEW_BLOCK, 1)
    print('Fix: Removed MSD filter (unix endings)')
else:
    print('ERROR: Exact match not found. Trying regex...')
    # Regex to catch variations
    pattern = r'await FlutterBluePlus\.startScan\(\s*//[^\r\n]*\r?\n\s*continuousUpdates:\s*true,\s*withMsd:\s*\[\s*MsdFilter\(76,\s*data:\s*\[2,\s*21\]\),\s*\],\s*removeIfGone:\s*const\s*Duration\(seconds:\s*10\),\s*\);'
    new_svc, n = re.subn(pattern, 'await FlutterBluePlus.startScan(\n        continuousUpdates: true,\n        removeIfGone: const Duration(seconds: 10),\n      );', svc)
    
    if n > 0:
        svc = new_svc
        print(f'Fix: Removed via regex ({n} match)')
    else:
        print('FAILED: Could not remove MSD filter automatically.')

with open(svc_path, 'wb') as f:
    f.write(svc.encode('utf-8'))

print('\nDone. Run: flutter build apk --release && flutter install')
