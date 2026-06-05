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
    await _tokenStore.saveToken(response.accessToken);
    return response;
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final payload = await _client.postJson(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );
    final response = AuthResponse.fromJson(payload);
    await _tokenStore.saveToken(response.accessToken);
    return response;
  }

  Future<void> logout() => _tokenStore.clearToken();
}
