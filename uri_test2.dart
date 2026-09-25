void main() {
  String url = 'https://hr.resourceplus.app/Login?token=ABC123XYZ#/dashboard?some=other';
  
  try {
    final uri = Uri.parse(url);
    final newParams = Map<String, dynamic>.from(uri.queryParameters);
    newParams['lang'] = '1';
    
    print('Original URL: $url');
    print('Query params: $newParams');
    print('New URL: ${uri.replace(queryParameters: newParams).toString()}');
  } catch(e) {
    print('Error: $e');
  }
}
