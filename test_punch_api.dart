import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://app.resourceplus.app/Mobile/api/Client/GetAttendancePunchData?usrEmail=mme&instanceName=nsp&Lang=1&Date=2026-09-18');
  print('Fetching: $url');
  
  try {
    final response = await http.get(url);
    print('STATUS: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty) {
        final firstDay = data.first;
        print('\n--- DAY LEVEL KEYS ---');
        print(firstDay.keys.toList());
        
        if (firstDay['PunchDetails'] != null) {
          final punches = firstDay['PunchDetails'] as List;
          if (punches.isNotEmpty) {
            print('\n--- PUNCH LEVEL KEYS ---');
            final firstPunch = punches.first;
            print(firstPunch.keys.toList());
            
            print('\n--- FIRST PUNCH DATA ---');
            firstPunch.forEach((key, value) {
              if (key == 'PunchImageByte' && value != null) {
                print('$key: [Base64 Data Length: ${value.toString().length}]');
              } else {
                print('$key: $value');
              }
            });
          } else {
            print('No punches for this day.');
          }
        }
      } else {
        print('Empty array or invalid JSON');
      }
    } else {
      print('Failed with body: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
