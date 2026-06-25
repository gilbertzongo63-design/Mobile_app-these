import 'api_client.dart';

class PushService {
  PushService({ApiClient? apiClient});

  static Future<void> initialize() async {
    // Push notifications disabled for web/demo compatibility
  }

  Future<String?> getDeviceToken() async {
    return null;
  }

  Future<void> registerTokenWithServer() async {
    // Not implemented
  }

  Future<void> unregisterTokenFromServer() async {
    // Not implemented
  }
}
