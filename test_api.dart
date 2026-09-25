import 'dart:convert';
import 'dart:io';

void main() async {
  final urlGet = Uri.parse('https://app.resourceplus.app/Mobile/api/Client/GetPortalUrl?Usremail=alex.abraham@netsoftpro.net&InstanceName=nsp&Lang=1');
  final urlPost = Uri.parse('https://app.resourceplus.app/Mobile/api/Client/GetPortalUrl');
  
  final httpClient = HttpClient()..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
  
  try {
    print('Testing GET:');
    var requestGet = await httpClient.getUrl(urlGet);
    var responseGet = await requestGet.close();
    var bodyGet = await responseGet.transform(utf8.decoder).join();
    print('Status: ${responseGet.statusCode}');
    print('Body: $bodyGet\n');

    print('Testing POST:');
    var requestPost = await httpClient.postUrl(urlPost);
    requestPost.headers.contentType = ContentType.json;
    requestPost.write(jsonEncode({
      'Usremail': 'alex.abraham@netsoftpro.net',
      'InstanceName': 'nsp',
      'Lang': 1
    }));
    var responsePost = await requestPost.close();
    var bodyPost = await responsePost.transform(utf8.decoder).join();
    print('Status: ${responsePost.statusCode}');
    print('Body: $bodyPost');

  } catch (e) {
    print('Error: $e');
  } finally {
    httpClient.close();
  }
}
