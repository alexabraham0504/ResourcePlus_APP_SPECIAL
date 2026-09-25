import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://app.resourceplus.app/Mobile/api/Client/GetAttendancePunchData';
  
  // Test with Month and Year
  final url1 = Uri.parse('$baseUrl?instanceName=nsp&usrEmail=alex&Lang=1&Month=9&Year=2026');
  try {
    final res = await http.get(url1);
    print('GET GetAttendancePunchData Month=9 Year=2026 -> ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
  } catch(e) { print(e); }
  
  // Test with StartDate and EndDate
  final url2 = Uri.parse('$baseUrl?instanceName=nsp&usrEmail=alex&Lang=1&StartDate=2026-09-01&EndDate=2026-09-30');
  try {
    final res = await http.get(url2);
    print('GET GetAttendancePunchData StartDate=2026-09-01 EndDate=2026-09-30 -> ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
  } catch(e) { print(e); }
}
