import 'package:flutter_test/flutter_test.dart';
import '../lib/app/modules/bluetooth_attendance/services/ibeacon_identity.dart';

void main() {
  test('stopped simulator and unrelated advertisements are not beacons', () {
    expect(IBeaconIdentity.parse(null), isNull);
    expect(IBeaconIdentity.parse([2, 21]), isNull);
    expect(IBeaconIdentity.parse(List.filled(23, 0)), isNull);
  });
  test('UUID, major and minor must all match', () {
    final packet = [2, 21, ...List.filled(16, 17), 0, 100, 0, 1, 197];
    final beacon = IBeaconIdentity.parse(packet)!;
    const uuid = '11111111-1111-1111-1111-111111111111';
    expect(beacon.matches(uuid, 100, 1), isTrue);
    expect(beacon.matches(uuid, 100, 2), isFalse);
    expect(beacon.matches(uuid, 101, 1), isFalse);
    expect(
      beacon.matches('22222222-2222-2222-2222-222222222222', 100, 1),
      isFalse,
    );
  });
}
