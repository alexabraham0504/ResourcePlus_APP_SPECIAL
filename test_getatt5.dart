import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://app.resourceplus.app/Mobile/api/Client/GetAttData';
  
  // Test 1: Add Emp_Number
  final url1 = Uri.parse('$baseUrl?instanceName=nsp&Usremail=alex&Emp_Number=0107&Lang=1');
  try {
    final res = await http.get(url1);
    print('GET Emp_Number -> ${res.statusCode}: ${res.body.length > 100 ? res.body.substring(0, 100) : res.body}');
  } catch(e) { print(e); }

  // Test 2: Add Date in DD/MM/YYYY
  final url2 = Uri.parse('$baseUrl?instanceName=nsp&Usremail=alex&Lang=1&Date=21/09/2026');
  try {
    final res = await http.get(url2);
    print('GET Date=21/09/2026 -> ${res.statusCode}: ${res.body.length > 100 ? res.body.substring(0, 100) : res.body}');
  } catch(e) { print(e); }

  // Test 3: Try Month and Year as strings
  final url3 = Uri.parse('$baseUrl?instanceName=nsp&Usremail=alex&Lang=1&Month=09&Year=2026');
  try {
    final res = await http.get(url3);
    print('GET Month=09&Year=2026 -> ${res.statusCode}: ${res.body.length > 100 ? res.body.substring(0, 100) : res.body}');
  } catch(e) { print(e); }
  
  // Test 4: Try username instead of Usremail
  final url4 = Uri.parse('$baseUrl?instanceName=nsp&username=alex&Lang=1');
  try {
    final res = await http.get(url4);
    print('GET username=alex -> ${res.statusCode}: ${res.body.length > 100 ? res.body.substring(0, 100) : res.body}');
  } catch(e) { print(e); }
}
