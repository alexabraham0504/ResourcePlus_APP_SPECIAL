import 'package:flutter_test/flutter_test.dart';
import '../lib/app/modules/bluetooth_attendance/services/beacon_scan_guard.dart';

void main() {
  final start = DateTime(2026, 1, 1);
  test('silence alone never authorizes checkout', () {
    final guard = BeaconScanGuard();
    expect(
      guard.canExit(start.add(const Duration(minutes: 5)), start),
      isFalse,
    );
  });
  test('fresh scan must complete confirmation window', () {
    final guard = BeaconScanGuard()
      ..scanStarted(start.add(const Duration(seconds: 16)));
    expect(
      guard.canExit(start.add(const Duration(seconds: 30)), start),
      isFalse,
    );
    expect(
      guard.canExit(start.add(const Duration(seconds: 31)), start),
      isTrue,
    );
  });
  test('beacon returns during verification', () {
    final guard = BeaconScanGuard()
      ..scanStarted(start.add(const Duration(seconds: 16)));
    expect(
      guard.canExit(
        start.add(const Duration(seconds: 40)),
        start.add(const Duration(seconds: 20)),
      ),
      isFalse,
    );
  });
  test('camera pause or scanner failure cancels confirmation', () {
    final guard = BeaconScanGuard()..scanStarted(start);
    guard.tick(start.add(const Duration(seconds: 10)), available: false);
    expect(
      guard.canExit(
        start.add(const Duration(minutes: 2)),
        start.subtract(const Duration(seconds: 1)),
      ),
      isFalse,
    );
  });
  test('service suspension does not count as observation time', () {
    final guard = BeaconScanGuard()..scanStarted(start);
    guard.tick(start, available: true);
    guard.tick(start.add(const Duration(minutes: 1)), available: true);
    expect(
      guard.needsVerification(start.subtract(const Duration(seconds: 1))),
      isTrue,
    );
  });
  test('normal timer ticks preserve a confirmation window', () {
    final guard = BeaconScanGuard()..scanStarted(start);
    for (final seconds in [0, 5, 10, 15]) {
      guard.tick(start.add(Duration(seconds: seconds)), available: true);
    }
    expect(
      guard.canExit(
        start.add(const Duration(seconds: 15)),
        start.subtract(const Duration(seconds: 16)),
      ),
      isTrue,
    );
  });
  test('only actual packets with matching UUID major minor count', () {
    const uuid = '11111111-1111-1111-1111-111111111111';
    final packet = [2, 21, ...List.filled(16, 17), 0, 100, 0, 1, 197];
    expect(matchesIBeacon(null, uuid, 100, 1), isFalse);
    expect(matchesIBeacon([2, 21], uuid, 100, 1), isFalse);
    expect(matchesIBeacon(packet, uuid, 100, 1), isTrue);
    expect(matchesIBeacon(packet, uuid, 100, 2), isFalse);
    expect(matchesIBeacon(packet, uuid, 101, 1), isFalse);
  });
}
