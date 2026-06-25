import '../models/auth_response.dart';
import 'api_client.dart';
import 'token_store.dart';

class AuthService {
  AuthService({
    ApiClient? client,
    TokenStore? tokenStore,
  })  : _tokenStore = tokenStore ?? TokenStore(),
        _client = client ?? ApiClient(tokenStore: tokenStore);

  final ApiClient _client;
  final TokenStore _tokenStore;

  Future<void> _saveTokens(AuthResponse response) async {
    if (response.refreshToken != null) {
      await _tokenStore.saveTokens(
          response.accessToken, response.refreshToken!);
    } else {
      await _tokenStore.saveAccessToken(response.accessToken);
    }
  }

  Future<void> _saveAuthResult(AuthResult result) async {
    if (result.authResponse != null) {
      await _saveTokens(result.authResponse!);
    }
  }

  Future<AuthResponse> register({
    required String email,
    required String fullName,
    required String password,
  }) async {
    final payload = await _client.postJson(
      '/auth/register',
      body: {
        'email': email,
        'full_name': fullName,
        'password': password,
      },
    );
    final response = AuthResponse.fromJson(payload);
    await _saveTokens(response);
    return response;
  }

  Future<AuthResult> login({
    required String email,
    required String password,
    String? mfaToken,
    String? mfaCode,
  }) async {
    final body = {
      'email': email,
      'password': password,
      if (mfaToken != null) 'mfa_token': mfaToken,
      if (mfaCode != null) 'mfa_code': mfaCode,
    };
    final payload = await _client.postJson(
      '/auth/login',
      body: body,
    );
    final result = AuthResult.fromJson(payload);
    await _saveAuthResult(result);
    return result;
  }

  Future<AuthResult> googleLogin({
    required String idToken,
    String? displayName,
    String? mfaToken,
    String? mfaCode,
  }) async {
    final body = {
      'id_token': idToken,
      if (displayName != null) 'display_name': displayName,
      if (mfaToken != null) 'mfa_token': mfaToken,
      if (mfaCode != null) 'mfa_code': mfaCode,
    };
    final payload = await _client.postJson(
      '/auth/google-login',
      body: body,
    );
    final result = AuthResult.fromJson(payload);
    await _saveAuthResult(result);
    return result;
  }

  Future<bool> refreshTokens() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final payload = await _client.postJson(
        '/auth/refresh',
        body: {'refresh_token': refreshToken},
      );
      final response = AuthResponse.fromJson(payload);
      await _saveTokens(response);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<String> requestEmailVerification({required String email}) async {
    final payload = await _client.postJson(
      '/auth/request-email-verification',
      body: {'email': email},
    );
    return payload['verification_token'] as String? ?? '';
  }

  Future<void> verifyEmail({required String token}) async {
    await _client.postJson(
      '/auth/verify-email',
      body: {'token': token},
    );
  }

  Future<String> requestPasswordReset({required String email}) async {
    final payload = await _client.postJson(
      '/auth/request-password-reset',
      body: {'email': email},
    );
    return payload['reset_token'] as String? ?? '';
  }

  Future<void> resetPassword(
      {required String token, required String password}) async {
    await _client.postJson(
      '/auth/reset-password',
      body: {'token': token, 'password': password},
    );
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _client.postJson(
          '/auth/logout',
          body: {'refresh_token': refreshToken},
          authRequired: true,
        );
      } catch (_) {
        // Ignore logout errors and clear local tokens anyway.
      }
    }
    await _tokenStore.clearTokens();
  }
}
