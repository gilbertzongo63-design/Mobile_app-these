import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import 'google_web_client_id.dart';

String? extractGoogleIdTokenFromUrl() {
  if (!kIsWeb) return null;

  final hash = html.window.location.hash;
  print('[GOOGLE_DEBUG] Hash from URL: "$hash"');
  if (hash.isEmpty || hash.length <= 1) return null;

  final hashContent = hash.substring(1);
  final params = Uri.splitQueryString(hashContent);
  final idToken = params['id_token'];
  print('[GOOGLE_DEBUG] id_token found: ${idToken != null && idToken.isNotEmpty}');
  if (idToken != null && idToken.isNotEmpty) {
    html.window.history.replaceState(
      null,
      '',
      html.window.location.pathname,
    );
    return idToken;
  }
  return null;
}

void redirectToGoogleOAuth({required List<String> scopes}) {
  final clientId = getGoogleWebClientId();
  if (clientId.isEmpty) {
    throw StateError('Google Web Client ID is missing.');
  }

  final origin = html.window.location.origin;
  final redirectUri = Uri.encodeComponent(origin);
  final scopeString = Uri.encodeComponent(scopes.join(' '));
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final nonce = 'gsi_${timestamp}_${timestamp.hashCode.toRadixString(36)}';

  final url = 'https://accounts.google.com/o/oauth2/v2/auth'
      '?client_id=$clientId'
      '&redirect_uri=$redirectUri'
      '&response_type=id_token'
      '&scope=openid%20$scopeString'
      '&nonce=$nonce'
      '&prompt=select_account';

  html.window.location.href = url;
}
