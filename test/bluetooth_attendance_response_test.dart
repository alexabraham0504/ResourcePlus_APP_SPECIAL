import 'package:flutter_test/flutter_test.dart';
import '../lib/app/modules/bluetooth_attendance/services/attendance_response.dart';

void main() {
  test('accepts explicit server acknowledgement', () {
    expect(attendanceAccepted(200, 'true'), isTrue);
    expect(attendanceAccepted(200, '"true"'), isTrue);
    expect(attendanceAccepted(200, 'true|Recorded'), isTrue);
  });
  test('does not mistake failure text for success', () {
    expect(attendanceAccepted(200, 'unsuccessful'), isFalse);
    expect(attendanceAccepted(200, 'not successful'), isFalse);
    expect(attendanceAccepted(200, 'false'), isFalse);
    expect(attendanceAccepted(500, 'true'), isFalse);
    expect(attendanceAccepted(200, '<html>success</html>'), isFalse);
  });
}
