import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://app.resourceplus.app/Mobile/api/Client/GetAttData';
  
  // Test 1: usrEmail (lowercase u)
  final url1 = Uri.parse('$baseUrl?instanceName=nsp&usrEmail=mme&Lang=1');
  print('\n=== TEST 1: GET with usrEmail ===');
  print('URL: $url1');
  try {
    final res1 = await http.get(url1);
    print('STATUS: ${res1.statusCode}');
    print('BODY: ${res1.body}');
  } catch(e) { print('Error: $e'); }

  // Test 2: Usremail (capital U)
  final url2 = Uri.parse('$baseUrl?instanceName=nsp&Usremail=mme&Lang=1');
  print('\n=== TEST 2: GET with Usremail ===');
  print('URL: $url2');
  try {
    final res2 = await http.get(url2);
    print('STATUS: ${res2.statusCode}');
    print('BODY: ${res2.body}');
  } catch(e) { print('Error: $e'); }

  // Test 3: POST with Usremail
  print('\n=== TEST 3: POST with Usremail ===');
  print('URL: $url2');
  try {
    final res3 = await http.post(url2);
    print('STATUS: ${res3.statusCode}');
    print('BODY: ${res3.body}');
  } catch(e) { print('Error: $e'); }
}
