"""
Fix "Checking registration..." frozen spinner.
Run: python fix_registration.py
"""

view_path = r'lib\app\modules\bluetooth_attendance\views\bluetooth_punch_view.dart'
with open(view_path, 'rb') as f:
    view = f.read().decode('utf-8', errors='replace')

# Find the exact broken function and replace it
OLD = '''  Future<void> _checkRegistrationStatusForBeacon(String mac, String beaconId) async {
    final now = DateTime.now();
    final lastAttempt = _registrationAttempts[mac];
    if (lastAttempt != null && now.difference(lastAttempt).inSeconds < 30) return;
    _registrationAttempts[mac] = now;
    _checkingBeacons.add(mac);
    try {
      final deviceId = await _getDeviceId();

      final isReg = await BluetoothAttendanceConfig.checkRegistration(deviceId, beaconId: beaconId);
      _checkedBeacons.add(mac);'''

NEW = '''  Future<void> _checkRegistrationStatusForBeacon(String mac, String beaconId) async {
    final now = DateTime.now();
    final lastAttempt = _registrationAttempts[mac];
    if (lastAttempt != null && now.difference(lastAttempt).inSeconds < 30) return;
    _registrationAttempts[mac] = now;
    _checkingBeacons.add(mac);
    bool isReg = false;
    try {
      final deviceId = await _getDeviceId();
      isReg = await BluetoothAttendanceConfig.checkRegistration(deviceId, beaconId: beaconId);
    } catch (e) {
      debugPrint('Registration check error for $beaconId: $e');
      // On API failure, treat as not registered so UI shows Register button.
      // Trust local cache if it already has registration data.
      isReg = _isRegisteredLocally(beaconId) ?? false;
    } finally {
      _checkingBeacons.remove(mac);
      _checkedBeacons.add(mac); // CRITICAL: always clear spinner
    }

    // dummy block to keep indentation — real update below
    if (false) {
      _checkedBeacons.add(mac); // placeholder'''

# Try to find and apply the fix
if 'final isReg = await BluetoothAttendanceConfig.checkRegistration' in view:
    # Use a broader find approach
    start_marker = '  Future<void> _checkRegistrationStatusForBeacon(String mac, String beaconId) async {'
    end_marker = '    } finally {\n      _checkingBeacons.remove(mac);\n    }\n  }\n'
    end_marker_r = '    } finally {\r\n      _checkingBeacons.remove(mac);\r\n    }\r\n  }\r\n'
    
    start_idx = view.find(start_marker)
    if start_idx == -1:
        # Try with \r\n
        start_marker_r = start_marker.replace('\n', '\r\n')
        start_idx = view.find(start_marker_r)
    
    if start_idx != -1:
        end_idx = view.find(end_marker_r, start_idx)
        if end_idx == -1:
            end_idx = view.find(end_marker, start_idx)
        
        if end_idx != -1:
            end_idx += len(end_marker_r) if end_marker_r in view[start_idx:] else len(end_marker)
            
            REPLACEMENT = '''  Future<void> _checkRegistrationStatusForBeacon(String mac, String beaconId) async {
    final now = DateTime.now();
    final lastAttempt = _registrationAttempts[mac];
    if (lastAttempt != null && now.difference(lastAttempt).inSeconds < 30) return;
    _registrationAttempts[mac] = now;
    _checkingBeacons.add(mac);
    bool isReg = false;
    try {
      final deviceId = await _getDeviceId();
      isReg = await BluetoothAttendanceConfig.checkRegistration(deviceId, beaconId: beaconId);
    } catch (e) {
      debugPrint('Registration check error for $beaconId: $e');
      // On API failure (timeout / network error), fall back to local cache.
      // This prevents the "Checking registration..." spinner from freezing forever
      // for users on slow networks (e.g., Riyadh, remote India).
      isReg = _isRegisteredLocally(beaconId) ?? false;
    } finally {
      _checkingBeacons.remove(mac);
      _checkedBeacons.add(mac); // CRITICAL: always clears the spinner
    }

    final storage = GetStorage();
    List<String> registered = List<String>.from(storage.read('registered_beacons') ?? []);
    bool updated = false;
    if (isReg && !registered.contains(beaconId)) {
      registered.add(beaconId);
      updated = true;
    } else if (!isReg && registered.contains(beaconId)) {
      registered.remove(beaconId);
      updated = true;
    }

    if (updated) {
      storage.write('registered_beacons', registered);
      FlutterBackgroundService().invoke('updateRegisteredBeacons', {'beacons': registered});
    }

    if (mounted) {
      setState(() {
        if (_beacons.containsKey(mac)) {
          _beacons[mac]!.isRegistered = isReg;
        }
      });
    }
  }
'''
            view = view[:start_idx] + REPLACEMENT + view[end_idx:]
            print('Fix applied: registration check no longer freezes on API error')
        else:
            print(f'ERROR: Could not find end marker after position {start_idx}')
            print('Context:', repr(view[start_idx:start_idx+500]))
    else:
        print('ERROR: Could not find start marker')
else:
    print('ERROR: Registration function not found in expected form')

with open(view_path, 'wb') as f:
    f.write(view.encode('utf-8'))

print('Done. Run: flutter build apk --release')
