class PushService {
  const PushService();

  static Future<void> initialize() async {
    // Push notifications are disabled by default in this mobile client.
    // Implement platform-specific push registration when the app is extended.
  }

  Future<String?> getDeviceToken() async {
    return null;
  }

  Future<void> registerTokenWithServer() async {
    // No device token available, so this is intentionally a no-op.
  }

  Future<void> unregisterTokenFromServer() async {
    // No registration state to clear.
  }
}
