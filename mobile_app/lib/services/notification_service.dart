import 'api_client.dart';

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String message;
  final bool isRead;
  final String createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class NotificationService {
  NotificationService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<NotificationItem>> fetchNotifications({int limit = 20}) async {
    final payload = await _client.getJson(
      '/notifications',
      queryParameters: {'limit': limit},
      authRequired: true,
    );

    final rawItems = payload['items'] as List<dynamic>? ?? <dynamic>[];
    return rawItems
        .map((item) =>
            NotificationItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
