import 'dart:convert';
import 'dart:io';

void main() async {
  final httpClient = HttpClient()..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
  
  // Test cases using 'alex' instead of the full email
  await _test(httpClient, 'GET - Lowercase Params (alex)', 'GET', 'https://app.resourceplus.app/Mobile/api/Client/GetPortalUrl?usrEmail=alex&instanceName=nsp&lang=1');
  await _test(httpClient, 'GET - Pascal Params (alex)', 'GET', 'https://app.resourceplus.app/Mobile/api/Client/GetPortalUrl?Usremail=alex&InstanceName=nsp&Lang=1');

  httpClient.close();
}

Future<void> _test(HttpClient client, String name, String method, String url) async {
  print('=============================================');
  print('TESTING: $name');
  try {
    HttpClientRequest request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    print('STATUS: ${response.statusCode}');
    print('BODY: $body');
  } catch (e) {
    print('ERROR: $e');
  }
}
