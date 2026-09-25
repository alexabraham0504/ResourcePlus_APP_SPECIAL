import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://app.resourceplus.app/Mobile/api/Client/GetAttData';
  
  print('=== POST with JSON body ===');
  try {
    final res = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'instanceName': 'nsp',
        'Usremail': 'alex',
        'Lang': '1'
      })
    );
    print('STATUS: ${res.statusCode}');
    if (res.body.isNotEmpty) {
      print('BODY: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
    } else {
      print('BODY is empty');
    }
  } catch(e) { print(e); }

  print('\n=== POST with Form Data ===');
  try {
    final res = await http.post(
      Uri.parse(baseUrl),
      body: {
        'instanceName': 'nsp',
        'Usremail': 'alex',
        'Lang': '1'
      }
    );
    print('STATUS: ${res.statusCode}');
    if (res.body.isNotEmpty) {
      print('BODY: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
    } else {
      print('BODY is empty');
    }
  } catch(e) { print(e); }

  print('\n=== GET with Usremail ===');
  try {
    final res = await http.get(Uri.parse('$baseUrl?instanceName=nsp&Usremail=alex&Lang=1'));
    print('STATUS: ${res.statusCode}');
    print('BODY: ${res.body.length > 100 ? res.body.substring(0, 100) : res.body}');
  } catch(e) { print(e); }
}
