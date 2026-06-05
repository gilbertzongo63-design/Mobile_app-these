import '../models/category_model.dart';
import 'api_client.dart';

class CategoryService {
  CategoryService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<CategoryModel>> fetchCategories() async {
    final payload = await _client.getJson('/categories');
    final items = (payload['items'] as List? ?? const [])
        .cast<Map>()
        .map((item) => CategoryModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return items;
  }
}
