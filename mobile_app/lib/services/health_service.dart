import '../models/api_health.dart';
import 'api_client.dart';

class HealthService {
  HealthService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<ApiHealth> fetchHealth() async {
    final payload = await _client.getJson('/health');
    return ApiHealth.fromJson(payload);
  }
}
