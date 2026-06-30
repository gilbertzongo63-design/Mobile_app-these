import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class UserService {
  UserService({ApiClient? client}) : _client = client ?? ApiClient();

  static const _persistedUserKey = 'persisted_current_user';
  static final ValueNotifier<UserModel?> currentUser =
      ValueNotifier<UserModel?>(null);

  final ApiClient _client;

  static Future<void> restoreCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final storedValue = prefs.getString(_persistedUserKey);
    if (storedValue == null || storedValue.isEmpty) {
      return;
    }
    try {
      final payload = jsonDecode(storedValue) as Map<String, dynamic>;
      currentUser.value = UserModel.fromJson(payload);
    } catch (_) {
      await prefs.remove(_persistedUserKey);
    }
  }

  static Future<void> setCurrentUser(UserModel? user) async {
    currentUser.value = user;
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_persistedUserKey);
      return;
    }
    await prefs.setString(_persistedUserKey, jsonEncode(user.toJson()));
  }

  Future<UserModel> fetchCurrentUser() async {
    final payload = await _client.getJson('/users/me', authRequired: true);
    _normalizeProfileImageUrl(payload);
    final user = UserModel.fromJson(payload);
    await setCurrentUser(user);
    return user;
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
    final user = UserModel.fromJson(payload);
    await setCurrentUser(user);
    return user;
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
    final user = UserModel.fromJson(payload);
    await setCurrentUser(user);
    return user;
  }

  Future<void> deleteAccount() async {
    await _client.deleteJson('/users/me', authRequired: true);
    await setCurrentUser(null);
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
