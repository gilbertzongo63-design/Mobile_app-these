import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../models/prediction_result.dart';
import 'api_client.dart';
import 'offline_prediction_queue.dart';
import '../config/api_config.dart';

class OfflineQueuedException implements Exception {
  OfflineQueuedException(this.message);

  final String message;

  @override
  String toString() => 'OfflineQueuedException: $message';
}

class PredictionService {
  PredictionService({ApiClient? client, OfflinePredictionQueue? offlineQueue})
      : _client = client ?? ApiClient(),
        _offlineQueue = offlineQueue ?? OfflinePredictionQueue();

  final ApiClient _client;
  final OfflinePredictionQueue _offlineQueue;

  Future<List<PredictionResult>> fetchPredictions() async {
    final payload = await _client.getJson('/predictions', authRequired: true);
    final items =
        (payload['items'] as List? ?? const []).cast<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      map['prediction_id'] = map['id'];
      _normalizeImageUrl(map);
      return PredictionResult.fromJson(map);
    }).toList();
    return items;
  }

  Future<PredictionResult> fetchPredictionDetail(int predictionId) async {
    final payload = await _client.getJson(
      '/predictions/$predictionId',
      authRequired: true,
    );
    final map = Map<String, dynamic>.from(payload);
    map['prediction_id'] = map['prediction_id'] ?? map['id'] ?? predictionId;
    _normalizeImageUrl(map);
    return PredictionResult.fromJson(map);
  }

  Future<PredictionResult> updatePredictionClass({
    required int predictionId,
    required String predictedClass,
  }) async {
    final payload = await _client.patchJson(
      '/predictions/$predictionId',
      body: {'predicted_class': predictedClass},
      authRequired: true,
    );
    final map = Map<String, dynamic>.from(payload);
    map['prediction_id'] = map['prediction_id'] ?? map['id'] ?? predictionId;
    _normalizeImageUrl(map);
    return PredictionResult.fromJson(map);
  }

  Future<void> deletePrediction(int predictionId) async {
    await _client.deleteJson(
      '/predictions/$predictionId',
      authRequired: true,
    );
  }

  Future<void> submitFeedback({
    required int predictionId,
    required int rating,
    required String comment,
  }) async {
    await _client.postJson(
      '/feedback',
      body: {
        'prediction_id': predictionId,
        'rating': rating,
        'comment': comment,
      },
      authRequired: true,
    );
  }

  Future<PredictionResult> predictImage({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    bool disableOcr = false,
    int topK = 3,
  }) async {
    if (filePath == null && bytes == null) {
      throw ArgumentError('Either bytes or filePath must be provided.');
    }

    try {
      return await _sendPredictionFile(
        filePath: filePath,
        bytes: bytes,
        filename: filename,
        disableOcr: disableOcr,
        topK: topK,
      );
    } catch (error) {
      if (_isOfflineError(error)) {
        if (filePath != null) {
          await _offlineQueue.enqueue(
            filePath: filePath,
            filename: filename,
            disableOcr: disableOcr,
            topK: topK,
          );
        } else if (bytes != null) {
          final tempPath = await OfflinePredictionQueue.saveBytesToTempFile(
              bytes.toList(), filename);
          await _offlineQueue.enqueue(
            filePath: tempPath,
            filename: filename,
            disableOcr: disableOcr,
            topK: topK,
          );
        }
        throw OfflineQueuedException(
          'Prediction saved locally and will be synchronized when the connection is restored.',
        );
      }
      rethrow;
    }
  }

  Future<PredictionResult> predictImageFile({
    required String filePath,
    required String filename,
    bool disableOcr = false,
    int topK = 3,
  }) async {
    try {
      return await _sendPredictionFile(
        filePath: filePath,
        filename: filename,
        disableOcr: disableOcr,
        topK: topK,
      );
    } catch (error) {
      if (_isOfflineError(error)) {
        await _offlineQueue.enqueue(
          filePath: filePath,
          filename: filename,
          disableOcr: disableOcr,
          topK: topK,
        );
        throw OfflineQueuedException(
          'Prediction saved locally and will be synchronized when the connection is restored.',
        );
      }
      rethrow;
    }
  }

  Future<PredictionResult> _sendPredictionFile({
    String? filePath,
    Uint8List? bytes,
    required String filename,
    required bool disableOcr,
    required int topK,
  }) async {
    final payload = bytes != null
        ? await _client.postMultipart(
            '/predict',
            fileField: 'image',
            bytes: bytes,
            filename: filename,
            queryParameters: {
              'disable_ocr': disableOcr,
              'top_k': topK,
            },
            authRequired: true,
          )
        : await _client.postMultipartFile(
            '/predict',
            fileField: 'image',
            filePath: filePath!,
            filename: filename,
            queryParameters: {
              'disable_ocr': disableOcr,
              'top_k': topK,
            },
            authRequired: true,
          );
    _normalizeImageUrl(payload);
    return PredictionResult.fromJson(payload);
  }

  Future<void> syncPendingPredictions() async {
    final pending = await _offlineQueue.loadPending();
    for (final item in pending) {
      final id = item['id'] as String?;
      final filePath = item['file_path'] as String?;
      final filename = item['filename'] as String?;
      final disableOcr = item['disable_ocr'] as bool? ?? false;
      final topK = item['top_k'] as int? ?? 3;

      if (id == null || filePath == null || filename == null) {
        if (id != null) {
          await _offlineQueue.remove(id);
        }
        continue;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        await _offlineQueue.remove(id);
        continue;
      }

      try {
        await _sendPredictionFile(
          filePath: filePath,
          filename: filename,
          disableOcr: disableOcr,
          topK: topK,
        );
        await _offlineQueue.remove(id);
      } catch (error) {
        if (!_isOfflineError(error)) {
          await _offlineQueue.remove(id);
        }
      }
    }
  }

  bool _isOfflineError(Object error) {
    if (error is OfflineQueuedException) {
      return true;
    }
    if (error is SocketException ||
        error is HttpException ||
        error is TimeoutException) {
      return true;
    }
    if (error is ApiException && error.statusCode >= 500) {
      return true;
    }
    return false;
  }

  void _normalizeImageUrl(Map<String, dynamic> payload) {
    final imageUrl = payload['image_url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.startsWith('http')) {
      return;
    }
    final base = Uri.parse(ApiConfig.baseUrl);
    payload['image_url'] = base.replace(path: imageUrl).toString();
  }
}
