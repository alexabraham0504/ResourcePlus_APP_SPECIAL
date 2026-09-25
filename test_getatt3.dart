import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://app.resourceplus.app/Mobile/api/Client/GetAttData';
  
  // Test 1: usrEmail=alex
  final url1 = Uri.parse('$baseUrl?instanceName=nsp&usrEmail=alex&Lang=1');
  try {
    final res = await http.get(url1);
    print('GET usrEmail=alex -> ${res.statusCode}: ${res.body.length > 100 ? res.body.substring(0, 100) : res.body}');
  } catch(e) { print(e); }

  // Test 2: Usremail=alex
  final url2 = Uri.parse('$baseUrl?instanceName=nsp&Usremail=alex&Lang=1');
  try {
    final res = await http.get(url2);
    print('GET Usremail=alex -> ${res.statusCode}: ${res.body.length > 100 ? res.body.substring(0, 100) : res.body}');
  } catch(e) { print(e); }

  // Test 3: Date
  final url3 = Uri.parse('$baseUrl?instanceName=nsp&usrEmail=alex&Lang=1&Date=2026-09-21');
  try {
    final res = await http.get(url3);
    print('GET Date=2026-09-21 -> ${res.statusCode}: ${res.body.length > 100 ? res.body.substring(0, 100) : res.body}');
  } catch(e) { print(e); }
  
  // Test 4: month and year
  final url4 = Uri.parse('$baseUrl?instanceName=nsp&usrEmail=alex&Lang=1&month=9&year=2026');
  try {
    final res = await http.get(url4);
    print('GET month=9&year=2026 -> ${res.statusCode}: ${res.body.length > 100 ? res.body.substring(0, 100) : res.body}');
  } catch(e) { print(e); }
}
