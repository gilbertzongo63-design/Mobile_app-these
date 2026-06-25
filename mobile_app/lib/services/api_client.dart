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
    return _requestWithRefresh(
      () async => http.get(
        _uri(path, queryParameters),
        headers: await _headers(authRequired: authRequired),
      ),
      authRequired: authRequired,
    );
  }

  Future<http.Response> getRawResponse(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authRequired = false,
  }) async {
    return _requestRawWithRefresh(
      () async => http.get(
        _uri(path, queryParameters),
        headers: await _headers(authRequired: authRequired),
      ),
      authRequired: authRequired,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    bool authRequired = false,
  }) async {
    return _requestWithRefresh(
      () async {
        final headers = await _headers(authRequired: authRequired)
          ..['Content-Type'] = 'application/json';
        return http.post(
          _uri(path),
          headers: headers,
          body: jsonEncode(body),
        );
      },
      authRequired: authRequired,
    );
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, dynamic> body,
    bool authRequired = false,
  }) async {
    return _requestWithRefresh(
      () async {
        final headers = await _headers(authRequired: authRequired)
          ..['Content-Type'] = 'application/json';
        return http.patch(
          _uri(path),
          headers: headers,
          body: jsonEncode(body),
        );
      },
      authRequired: authRequired,
    );
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool authRequired = false,
  }) async {
    return _requestWithRefresh(
      () async => http.delete(
        _uri(path),
        headers: await _headers(authRequired: authRequired),
      ),
      authRequired: authRequired,
    );
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

    return _multipartRequestWithRefresh(
      () async {
        final request =
            http.MultipartRequest('POST', _uri(path, queryParameters))
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
        return request;
      },
      authRequired: authRequired,
    );
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
    return _multipartRequestWithRefresh(
      () async {
        final request =
            http.MultipartRequest('POST', _uri(path, queryParameters))
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

        return request;
      },
      authRequired: authRequired,
    );
  }

  Future<Map<String, dynamic>> _multipartRequestWithRefresh(
    Future<http.MultipartRequest> Function() buildRequest, {
    bool authRequired = false,
  }) async {
    final response = await _sendMultipartRequest(await buildRequest());
    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshToken();
      if (!refreshed) {
        return _decodeResponse(response);
      }
      final retryResponse = await _sendMultipartRequest(await buildRequest());
      return _decodeResponse(retryResponse);
    }
    return _decodeResponse(response);
  }

  Future<http.Response> _sendMultipartRequest(
      http.MultipartRequest request) async {
    final streamed = await request.send();
    return await http.Response.fromStream(streamed);
  }

  Future<bool> _refreshToken() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await http.post(
        _uri('/auth/refresh'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      final payload = _decodeResponse(response);
      final accessToken = payload['access_token'] as String?;
      final refreshTokenValue = payload['refresh_token'] as String?;

      if (accessToken == null || accessToken.isEmpty) {
        await _tokenStore.clearTokens();
        return false;
      }

      if (refreshTokenValue != null && refreshTokenValue.isNotEmpty) {
        await _tokenStore.saveTokens(accessToken, refreshTokenValue);
      } else {
        await _tokenStore.saveAccessToken(accessToken);
      }

      return true;
    } catch (_) {
      await _tokenStore.clearTokens();
      return false;
    }
  }

  Future<http.Response> _requestRawWithRefresh(
    Future<http.Response> Function() sendRequest, {
    bool authRequired = false,
  }) async {
    final response = await sendRequest();
    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshToken();
      if (!refreshed) {
        return response;
      }
      final retryResponse = await sendRequest();
      return retryResponse;
    }
    return response;
  }

  Future<Map<String, dynamic>> _requestWithRefresh(
    Future<http.Response> Function() sendRequest, {
    bool authRequired = false,
  }) async {
    final response = await sendRequest();
    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshToken();
      if (!refreshed) {
        return _decodeResponse(response);
      }
      final retryResponse = await sendRequest();
      return _decodeResponse(retryResponse);
    }
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
