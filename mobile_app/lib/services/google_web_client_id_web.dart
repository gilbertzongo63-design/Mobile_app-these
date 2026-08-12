// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html';
import 'dart:js' as js;

String getGoogleWebClientId() {
  try {
    final clientId = js.context['__ECOSORT_GOOGLE_CLIENT_ID'];
    if (clientId != null && clientId is String && clientId.isNotEmpty) {
      return clientId;
    }
  } catch (_) {}

  final meta =
      document.head?.querySelector('meta[name="google-signin-client_id"]');
  if (meta == null) {
    return '';
  }

  final content = meta.getAttribute('content');
  return content?.trim() ?? '';
}
