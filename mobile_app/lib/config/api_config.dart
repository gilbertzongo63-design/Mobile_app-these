import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // Web/Desktop: 127.0.0.1
  // Android emulator: 10.0.2.2
  // Physical phone: pass --dart-define=API_BASE_URL=http://IP_DU_PC:8000
  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      return _overrideBaseUrl;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8080';
    }
    return 'http://10.0.2.2:8080';
  }
}
