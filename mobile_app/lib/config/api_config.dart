import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static List<String> get baseUrls {
    final urls = <String>[];
    if (_overrideBaseUrl.isNotEmpty) {
      urls.add(_overrideBaseUrl);
    }
    if (kIsWeb) {
      urls.add('http://127.0.0.1:8000');
      urls.add('http://localhost:8000');
    } else {
      urls.add('http://192.168.11.118:8000');
      urls.add('http://10.0.2.2:8000');
      urls.add('http://127.0.0.1:8000');
      urls.add('http://localhost:8000');
    }
    return urls;
  }

  static String get baseUrl => baseUrls.first;
}
