import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/app_config.dart';
import '../../core/network/http_api_client.dart';

class NotificationApiService {
  final HttpApiClient _http;
  WebSocketChannel? _channel;

  NotificationApiService({HttpApiClient? http})
    : _http = http ?? HttpApiClient();

  Future<List<Map<String, dynamic>>> getNotifications(String userEmail) async {
    final response = await _http.getJsonList(
      Uri.parse('${AppConfig.notificationUrl}/api/v1/notifications/$userEmail'),
    );
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markAsRead(String notificationId) async {
    await _http.patchJson(
      Uri.parse('${AppConfig.notificationUrl}/api/v1/notifications/$notificationId/read'),
    );
  }

  Stream<dynamic> connectToNotifications(String userEmail) {
    final wsUrl = AppConfig.notificationUrl.replaceFirst('http', 'ws');
    _channel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/ws/notifications/$userEmail'),
    );
    return _channel!.stream;
  }

  void disconnect() {
    _channel?.sink.close();
  }
  Future<Map<String, dynamic>> broadcastNotification(String title, String summary, String description, String type) {
    return _http.postJson(
      Uri.parse('${AppConfig.notificationUrl}/api/v1/notifications/broadcast'),
      body: {
        'user_email': 'all',
        'title': title,
        'summary': summary,
        'description': description,
        'type': type
      },
    );
  }

}
