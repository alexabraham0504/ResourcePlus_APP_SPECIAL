/// A departure needs a fresh scan window after signal loss. Pauses and delayed
/// timer callbacks invalidate the window; elapsed wall time alone is not proof.
class BeaconScanGuard {
  static const window = Duration(seconds: 15); // 15s confirmation after scan restart (was 30s)
  DateTime? _verificationStarted;
  DateTime? _lastTick;

  void invalidate() => _verificationStarted = null;

  void tick(DateTime now, {required bool available}) {
    // Only invalidate when Bluetooth is genuinely off or camera is pausing the scan.
    // Do NOT invalidate on timer-gap alone: Samsung Doze can delay the 10s periodic
    // timer by 30-40s which previously caused the guard to reset on every Doze cycle,
    // permanently blocking OUT detection on Samsung Galaxy devices.
    if (!available) invalidate();
    _lastTick = now;
  }

  // ??= means: only set the start timestamp once per loss event.
  // Subsequent scan restarts (Samsung killing the scan) will NOT push the
  // verification window forward — the clock continues from the original start.
  void scanStarted(DateTime now) => _verificationStarted ??= now;

  bool needsVerification(DateTime lastSeen) =>
      _verificationStarted == null || !lastSeen.isBefore(_verificationStarted!);

  bool canExit(DateTime now, DateTime lastSeen) =>
      !needsVerification(lastSeen) &&
      now.difference(_verificationStarted!) >= window &&
      now.difference(lastSeen) >= window;
}

bool matchesIBeacon(List<int>? data, String uuid, int major, int minor) {
  if (data == null || data.length < 23 || data[0] != 2 || data[1] != 21)
    return false;
  final packetUuid = data
      .sublist(2, 18)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return packetUuid == uuid.replaceAll('-', '').toLowerCase() &&
      ((data[18] << 8) | data[19]) == major &&
      ((data[20] << 8) | data[21]) == minor;
}
