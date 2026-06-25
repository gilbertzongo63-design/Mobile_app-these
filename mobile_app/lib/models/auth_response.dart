import 'user_model.dart';

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
    this.refreshToken,
    this.verificationToken,
  });

  final String accessToken;
  final String tokenType;
  final UserModel user;
  final String? refreshToken;
  final String? verificationToken;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      user:
          UserModel.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
      refreshToken: json['refresh_token'] as String?,
      verificationToken: json['verification_token'] as String?,
    );
  }
}

class AuthResult {
  const AuthResult({
    required this.mfaRequired,
    this.authResponse,
    this.mfaToken,
    this.mfaMethod,
    this.mfaCode,
  });

  final AuthResponse? authResponse;
  final bool mfaRequired;
  final String? mfaToken;
  final String? mfaMethod;
  final String? mfaCode;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    if (json['mfa_required'] == true) {
      return AuthResult(
        mfaRequired: true,
        mfaToken: json['mfa_token'] as String?,
        mfaMethod: json['mfa_method'] as String?,
        mfaCode: json['mfa_code'] as String?,
      );
    }
    return AuthResult(
      mfaRequired: false,
      authResponse: AuthResponse.fromJson(json),
    );
  }
}
