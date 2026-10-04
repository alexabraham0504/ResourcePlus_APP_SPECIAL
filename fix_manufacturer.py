"""
TWO CRITICAL FIXES:
1. Scan ALL manufacturer data company IDs for iBeacon format (not just Apple=76).
   Android V Beacon apps (like com.fruitmobile.app.vbeacon.trial) may use a
   different company ID — causing every packet to be silently dropped.

2. Beacon list API only requires instanceName (not usrEmail). Fix the guard
   condition so beacons are fetched even when usrEmail is empty.

Run: python fix_manufacturer.py
"""
import re

SVC_PATH = r'lib\app\modules\bluetooth_attendance\services\background_tracking_service.dart'
CFG_PATH = r'lib\app\modules\bluetooth_attendance\config\bluetooth_attendance_config.dart'

# ─── Fix 1: Check ALL manufacturer data company IDs ───────────────────────────
with open(SVC_PATH, 'rb') as f:
    svc = f.read().decode('utf-8', errors='replace')

OLD_PACKET = "      final packet = result.advertisementData.manufacturerData[76];\n      // Bounded diagnostics: no device addresses, employee data or per-packet spam.\n      if (packet != null && packet.length >= 23 &&\n          packet[0] == 2 && packet[1] == 21) {"
OLD_PACKET_R = "      final packet = result.advertisementData.manufacturerData[76];\r\n      // Bounded diagnostics: no device addresses, employee data or per-packet spam.\r\n      if (packet != null \u0026\u0026 packet.length >= 23 &&\r\n          packet[0] == 2 && packet[1] == 21) {"

NEW_PACKET = """      // Scan ALL manufacturer data entries for iBeacon format (type=0x02, len=0x15).
      // Apple iPhones use company ID 76. Android beacon apps (e.g. V Beacon, Beacon Simulator)
      // may use a different company ID. By checking all entries we detect both.
      List<int>? packet;
      int? packetCompanyId;
      for (final entry in result.advertisementData.manufacturerData.entries) {
        final d = entry.value;
        if (d.length >= 23 && d[0] == 2 && d[1] == 21) {
          packet = d;
          packetCompanyId = entry.key;
          break;
        }
      }
      // Bounded diagnostics
      if (packet != null) {"""

if OLD_PACKET_R in svc:
    svc = svc.replace(OLD_PACKET_R, NEW_PACKET.replace('\n', '\r\n'), 1)
    print('Fix 1a: Replaced Apple-only packet read with all-company-ID scan (windows endings)')
elif OLD_PACKET in svc:
    svc = svc.replace(OLD_PACKET, NEW_PACKET, 1)
    print('Fix 1a: Applied (unix endings)')
else:
    # Try regex
    pattern = r'final packet = result\.advertisementData\.manufacturerData\[76\];[\r\n]+[ \t]*//.+[\r\n]+[ \t]*if \(packet != null'
    if re.search(pattern, svc):
        svc = re.sub(pattern,
            'List<int>? packet;\n      int? packetCompanyId;\n      for (final entry in result.advertisementData.manufacturerData.entries) {\n        final d = entry.value;\n        if (d.length >= 23 && d[0] == 2 && d[1] == 21) {\n          packet = d;\n          packetCompanyId = entry.key;\n          break;\n        }\n      }\n      if (packet != null',
            svc, count=1)
        print('Fix 1a: Applied via regex')
    else:
        print('Fix 1a FAILED: Pattern not found')
        print('Manual edit: change `manufacturerData[76]` to scan all entries')

# Fix the closing brace of the if block and add company ID to diagnostics
OLD_DIAG = "          debugPrint('[BLE Scan] iBeacon uuid=${identity.substring(0, 32)} '\n              'major=${(packet[18] << 8) | packet[19]} '\n              'minor=${(packet[20] << 8) | packet[21]} matched=$matched');\n        }\n      }\n      String name = '';"
OLD_DIAG_R = "          debugPrint('[BLE Scan] iBeacon uuid=${identity.substring(0, 32)} '\r\n              'major=${(packet[18] << 8) | packet[19]} '\r\n              'minor=${(packet[20] << 8) | packet[21]} matched=$matched');\r\n        }\r\n      }\r\n      String name = '';"

NEW_DIAG = """          debugPrint('[BLE Scan] iBeacon companyId=$packetCompanyId uuid=${identity.substring(0, 32)} '
              'major=${(packet[18] << 8) | packet[19]} '
              'minor=${(packet[20] << 8) | packet[21]} matched=$matched');
        }
      }
      String name = '';"""

if OLD_DIAG_R in svc:
    svc = svc.replace(OLD_DIAG_R, NEW_DIAG.replace('\n', '\r\n'), 1)
    print('Fix 1b: Updated diagnostic to log company ID (windows)')
elif OLD_DIAG in svc:
    svc = svc.replace(OLD_DIAG, NEW_DIAG, 1)
    print('Fix 1b: Updated diagnostic to log company ID (unix)')
else:
    print('Fix 1b: Diagnostic update skipped (non-critical)')

with open(SVC_PATH, 'wb') as f:
    f.write(svc.encode('utf-8'))
    print('Service file written')

# ─── Fix 2: Beacon API only needs instanceName ────────────────────────────────
with open(CFG_PATH, 'rb') as f:
    cfg = f.read().decode('utf-8', errors='replace')

OLD_GUARD = "    if (instanceName.isEmpty || usrEmail.isEmpty) {\n      debugPrint('[BLE Beacons] Missing credentials — using fallback beacons');\n      return;\n    }"
OLD_GUARD_R = "    if (instanceName.isEmpty || usrEmail.isEmpty) {\r\n      debugPrint('[BLE Beacons] Missing credentials — using fallback beacons');\r\n      return;\r\n    }"

NEW_GUARD = """    // Only instanceName is required by this API (Postman confirmed usrEmail is optional).
    // On fresh install / cleared data, usrEmail may not be in the background isolate yet.
    if (instanceName.isEmpty) {
      debugPrint('[BLE Beacons] No instanceName — using fallback beacons');
      return;
    }"""

if OLD_GUARD_R in cfg:
    cfg = cfg.replace(OLD_GUARD_R, NEW_GUARD.replace('\n', '\r\n'), 1)
    print('Fix 2: Beacon API guard fixed — only instanceName required (windows)')
elif OLD_GUARD in cfg:
    cfg = cfg.replace(OLD_GUARD, NEW_GUARD, 1)
    print('Fix 2: Applied (unix)')
else:
    print('Fix 2 FAILED: Guard pattern not found. Manual edit needed.')
    print('  Find: if (instanceName.isEmpty || usrEmail.isEmpty)')
    print('  Change to: if (instanceName.isEmpty)')

with open(CFG_PATH, 'wb') as f:
    f.write(cfg.encode('utf-8'))
    print('Config file written')

print('\nDone. Run: flutter build apk --release && flutter install')
