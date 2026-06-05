import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_store.dart';

class ApiClient {
  ApiClient({TokenStore? tokenStore})
      : _tokenStore = tokenStore ?? TokenStore();

  final TokenStore _tokenStore;

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final base = Uri.parse(ApiConfig.baseUrl);
    return base.replace(
      path: path.startsWith('/') ? path : '/$path',
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Future<Map<String, String>> _headers({bool authRequired = false}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (authRequired) {
      final token = await _tokenStore.readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authRequired = false,
  }) async {
    final response = await http.get(
      _uri(path, queryParameters),
      headers: await _headers(authRequired: authRequired),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    bool authRequired = false,
  }) async {
    final headers = await _headers(authRequired: authRequired)
      ..['Content-Type'] = 'application/json';

    final response = await http.post(
      _uri(path),
      headers: headers,
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, dynamic> body,
    bool authRequired = false,
  }) async {
    final headers = await _headers(authRequired: authRequired)
      ..['Content-Type'] = 'application/json';

    final response = await http.patch(
      _uri(path),
      headers: headers,
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool authRequired = false,
  }) async {
    final response = await http.delete(
      _uri(path),
      headers: await _headers(authRequired: authRequired),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String fileField,
    Uint8List? bytes,
    String? filePath,
    required String filename,
    Map<String, dynamic>? fields,
    Map<String, dynamic>? queryParameters,
    bool authRequired = false,
  }) async {
    if (bytes == null && filePath == null) {
      throw ArgumentError('Either bytes or filePath must be provided.');
    }

    final request = http.MultipartRequest('POST', _uri(path, queryParameters))
      ..headers.addAll(await _headers(authRequired: authRequired))
      ..files.add(
        filePath != null
            ? await http.MultipartFile.fromPath(
                fileField,
                filePath,
                filename: filename,
              )
            : http.MultipartFile.fromBytes(
                fileField,
                bytes!,
                filename: filename,
              ),
      );

    if (fields != null) {
      request.fields.addAll(
        fields.map((key, value) => MapEntry(key, value.toString())),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> postMultipartFile(
    String path, {
    required String fileField,
    required String filePath,
    required String filename,
    Map<String, dynamic>? fields,
    Map<String, dynamic>? queryParameters,
    bool authRequired = false,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path, queryParameters))
      ..headers.addAll(await _headers(authRequired: authRequired))
      ..files.add(
        await http.MultipartFile.fromPath(
          fileField,
          filePath,
          filename: filename,
        ),
      );

    if (fields != null) {
      request.fields.addAll(
        fields.map((key, value) => MapEntry(key, value.toString())),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (response.statusCode >= 400) {
      throw ApiException(
        message: payload['detail'] as String? ?? 'API request failed',
        statusCode: response.statusCode,
      );
    }
    return payload;
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.statusCode,
  });

  final String message;
  final int statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
