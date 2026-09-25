import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://app.resourceplus.app/Mobile/api/FaceTemplate?instanceName=nsp&usrEmail=alex.abraham@netsoftpro.net');
  final httpClient = HttpClient()..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
  
  try {
    final request = await httpClient.getUrl(url);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    
    print('Status Code: ${response.statusCode}');
    if (response.statusCode == 200) {
      if (body.contains('embedding')) {
        print('SUCCESS: Face template exists on the backend database!');
        // Don't print the whole huge embedding
        print('Response size: ${body.length} bytes');
      } else {
        print('No embedding found in response. Body: $body');
      }
    } else {
      print('Failed. Body: $body');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    httpClient.close();
  }
}
