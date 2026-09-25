import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://app.resourceplus.app/Mobile/api/Client/GetAttData';
  
  // Test 4: POST with usrEmail (lowercase)
  final url4 = Uri.parse('$baseUrl?instanceName=nsp&usrEmail=mme&Lang=1');
  print('\n=== TEST 4: POST with usrEmail ===');
  print('URL: $url4');
  try {
    final res4 = await http.post(url4);
    print('STATUS: ${res4.statusCode}');
    print('BODY: ${res4.body}');
  } catch(e) { print('Error: $e'); }

  // Test 5: GET with Month and Year
  final url5 = Uri.parse('$baseUrl?instanceName=nsp&usrEmail=mme&Lang=1&Month=9&Year=2026');
  print('\n=== TEST 5: GET with Month and Year ===');
  print('URL: $url5');
  try {
    final res5 = await http.get(url5);
    print('STATUS: ${res5.statusCode}');
    print('BODY: ${res5.body}');
  } catch(e) { print('Error: $e'); }
  
  // Test 6: POST with JSON body
  print('\n=== TEST 6: POST with JSON body ===');
  try {
    final res6 = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'instanceName': 'nsp',
        'usrEmail': 'mme',
        'Lang': '1'
      })
    );
    print('STATUS: ${res6.statusCode}');
    print('BODY: ${res6.body}');
  } catch(e) { print('Error: $e'); }
}
