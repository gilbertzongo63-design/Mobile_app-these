import 'dart:typed_data';

import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class UserService {
  UserService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<UserModel> fetchCurrentUser() async {
    final payload = await _client.getJson('/users/me', authRequired: true);
    _normalizeProfileImageUrl(payload);
    return UserModel.fromJson(payload);
  }

  Future<UserModel> updateProfile({
    required String fullName,
  }) async {
    final payload = await _client.patchJson(
      '/users/me',
      body: {'full_name': fullName},
      authRequired: true,
    );
    _normalizeProfileImageUrl(payload);
    return UserModel.fromJson(payload);
  }

  Future<UserModel> uploadProfilePhoto({
    Uint8List? bytes,
    String? filePath,
    required String filename,
  }) async {
    final payload = filePath != null
        ? await _client.postMultipartFile(
            '/users/me/photo',
            fileField: 'image',
            filePath: filePath,
            filename: filename,
            authRequired: true,
          )
        : await _client.postMultipart(
            '/users/me/photo',
            fileField: 'image',
            bytes: bytes,
            filename: filename,
            authRequired: true,
          );
    _normalizeProfileImageUrl(payload);
    return UserModel.fromJson(payload);
  }

  void _normalizeProfileImageUrl(Map<String, dynamic> payload) {
    final imageUrl = payload['profile_image_url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.startsWith('http')) {
      return;
    }
    final base = Uri.parse(ApiConfig.baseUrl);
    payload['profile_image_url'] = base.replace(path: imageUrl).toString();
  }
}
