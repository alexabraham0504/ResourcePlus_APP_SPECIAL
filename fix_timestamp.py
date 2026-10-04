"""
Fix: Remove dangerous timestamp check that blocks Samsung scanning.
Run: python fix_timestamp.py
"""
import re

svc_path = r'lib\app\modules\bluetooth_attendance\services\background_tracking_service.dart'
with open(svc_path, 'rb') as f:
    svc = f.read().decode('utf-8', errors='replace')

OLD = '      // Ignore stale cached results emitted by Android\'s continuous scanner\r\n      if (now.difference(result.timeStamp).inSeconds > 10) continue;\r\n'
OLD_U = '      // Ignore stale cached results emitted by Android\'s continuous scanner\n      if (now.difference(result.timeStamp).inSeconds > 10) continue;\n'

if OLD in svc:
    svc = svc.replace(OLD, '', 1)
    print('Fix: Removed timestamp check (windows)')
elif OLD_U in svc:
    svc = svc.replace(OLD_U, '', 1)
    print('Fix: Removed timestamp check (unix)')
else:
    # Try regex
    pattern = r'[ \t]*// Ignore stale cached results.*?if \(now\.difference\(result\.timeStamp\)\.inSeconds > 10\) continue;[\r\n]+'
    new_svc, n = re.subn(pattern, '', svc)
    if n > 0:
        svc = new_svc
        print('Fix: Removed timestamp check via regex')
    else:
        print('FAILED: Could not find timestamp check. It may already be removed.')

with open(svc_path, 'wb') as f:
    f.write(svc.encode('utf-8'))

print('\nDone. Run: flutter build apk --release')
