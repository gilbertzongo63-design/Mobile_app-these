// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html';

String getGoogleWebClientId() {
  final meta =
      document.head?.querySelector('meta[name="google-signin-client_id"]');
  if (meta == null) {
    return '';
  }

  final content = meta.getAttribute('content');
  return content?.trim() ?? '';
}
