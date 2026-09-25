import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://app.resourceplus.app/Mobile/api/Client/GetHomeData';
  
  final url1 = Uri.parse('$baseUrl?instanceName=nsp&usrEmail=alex&Lang=1');
  try {
    final res = await http.get(url1);
    print('GET GetHomeData -> ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
  } catch(e) { print(e); }
}
