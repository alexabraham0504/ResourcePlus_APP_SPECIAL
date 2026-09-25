import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://app.resourceplus.app/Mobile/api/Client/GetHomeData';
  
  final url1 = Uri.parse('$baseUrl?instanceName=nsp&usrEmail=alex&Lang=1');
  try {
    final res = await http.get(url1);
    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(res.body);
      print('GetHomeData keys: ${data.keys.toList()}');
    }
  } catch(e) { print(e); }

  final url2 = Uri.parse('https://app.resourceplus.app/Mobile/api/Client/GetAttData?instanceName=nsp&Usremail=alex&Lang=1&Month=9&Year=2026');
  try {
    final res = await http.post(url2);
    print('\nPOST GetAttData with Month/Year -> ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
  } catch(e) { print(e); }
}
