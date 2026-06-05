import 'dart:typed_data';

import '../models/prediction_result.dart';
import 'api_client.dart';
import '../config/api_config.dart';

class PredictionService {
  PredictionService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<PredictionResult>> fetchPredictions() async {
    final payload = await _client.getJson('/predictions', authRequired: true);
    final items = (payload['items'] as List? ?? const [])
        .cast<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          map['prediction_id'] = map['id'];
          _normalizeImageUrl(map);
          return PredictionResult.fromJson(map);
        })
        .toList();
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

  Future<PredictionResult> predictImage({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    bool disableOcr = false,
    int topK = 3,
  }) async {
    final payload = await _client.postMultipart(
      '/predict',
      fileField: 'image',
      bytes: bytes,
      filePath: filePath,
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

  Future<PredictionResult> predictImageFile({
    required String filePath,
    required String filename,
    bool disableOcr = false,
    int topK = 3,
  }) async {
    final payload = await _client.postMultipartFile(
      '/predict',
      fileField: 'image',
      filePath: filePath,
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

  void _normalizeImageUrl(Map<String, dynamic> payload) {
    final imageUrl = payload['image_url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.startsWith('http')) {
      return;
    }
    final base = Uri.parse(ApiConfig.baseUrl);
    payload['image_url'] = base.replace(path: imageUrl).toString();
  }
}
