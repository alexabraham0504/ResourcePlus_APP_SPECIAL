import 'dart:convert';
import 'dart:io';

void main() async {
  final httpClient = HttpClient()..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
  
  // Test cases
  await _test(httpClient, 'GET - Lowercase Params', 'GET', 'https://app.resourceplus.app/Mobile/api/Client/GetPortalUrl?usrEmail=alex.abraham@netsoftpro.net&instanceName=nsp&lang=1');
  await _test(httpClient, 'GET - Pascal Params', 'GET', 'https://app.resourceplus.app/Mobile/api/Client/GetPortalUrl?Usremail=alex.abraham@netsoftpro.net&InstanceName=nsp&Lang=1');
  await _test(httpClient, 'POST - JSON Body', 'POST', 'https://app.resourceplus.app/Mobile/api/Client/GetPortalUrl', jsonBody: {'usrEmail': 'alex.abraham@netsoftpro.net', 'instanceName': 'nsp', 'lang': 1});
  await _test(httpClient, 'POST - Form Body', 'POST', 'https://app.resourceplus.app/Mobile/api/Client/GetPortalUrl', formBody: 'usrEmail=alex.abraham%40netsoftpro.net&instanceName=nsp&lang=1');
  await _test(httpClient, 'POST - Query Params', 'POST', 'https://app.resourceplus.app/Mobile/api/Client/GetPortalUrl?usrEmail=alex.abraham@netsoftpro.net&instanceName=nsp&lang=1');

  httpClient.close();
}

Future<void> _test(HttpClient client, String name, String method, String url, {Map<String, dynamic>? jsonBody, String? formBody}) async {
  print('=============================================');
  print('TESTING: $name');
  try {
    HttpClientRequest request;
    if (method == 'GET') {
      request = await client.getUrl(Uri.parse(url));
    } else {
      request = await client.postUrl(Uri.parse(url));
      if (jsonBody != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(jsonBody));
      } else if (formBody != null) {
        request.headers.contentType = ContentType.parse('application/x-www-form-urlencoded');
        request.write(formBody);
      }
    }
    
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    print('STATUS: ${response.statusCode}');
    print('BODY: $body');
  } catch (e) {
    print('ERROR: $e');
  }
}
