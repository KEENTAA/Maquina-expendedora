import 'dart:convert';
import 'dart:typed_data';
import '../../controllers/admin_dashboard_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/notification_controller.dart';
import '../../../domain/entities/app_notification.dart';

final Map<String, Uint8List> _notifImageCache = {};

Uint8List? _decodeBase64Safe(String? base64Str) {
  if (base64Str == null || base64Str.isEmpty) return null;
  if (_notifImageCache.containsKey(base64Str)) {
    return _notifImageCache[base64Str];
  }
  try {
    String cleanStr = base64Str.trim();
    if (cleanStr.contains(',')) {
      cleanStr = cleanStr.split(',').last.trim();
    }
    cleanStr = cleanStr.replaceAll(RegExp(r'\s+'), '');
    final bytes = base64Decode(cleanStr);
    if (_notifImageCache.length > 50) _notifImageCache.clear();
    _notifImageCache[base64Str] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationController>();
    final notifications = controller.notifications;
    final adminController = context.watch<AdminDashboardController>();
    final bannerTitle = adminController.banner['title'] ?? '';
    final bannerConcept = adminController.banner['concept'] ?? '';
    final bannerImage = adminController.banner['image_base64'] ?? '';
    
    final bool hasAd = bannerTitle.isNotEmpty || bannerConcept.isNotEmpty || bannerImage.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () {
                for (var n in notifications) {
                  if (!n.isRead) controller.markAsRead(n.id);
                }
              },
              child: const Text('Leer todas'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No tienes notificaciones aún', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length + (hasAd ? 1 : 0),
              itemBuilder: (context, index) {
                if (hasAd && index == 0) {
                   return _AdNotificationTile(title: bannerTitle, concept: bannerConcept, imageBase64: bannerImage);
                }
                final n = notifications[hasAd ? index - 1 : index];
                return _NotificationTile(notification: n);
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: notification.isRead ? 0 : 2,
      color: notification.isRead ? Colors.white : Colors.indigo.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getColor(notification.type).withValues(alpha: 0.1),
          child: Icon(_getIcon(notification.type), color: _getColor(notification.type)),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(
          notification.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _formatTime(notification.createdAt),
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        onTap: () {
          if (!notification.isRead) {
            context.read<NotificationController>().markAsRead(notification.id);
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NotificationDetailScreen(notification: notification),
            ),
          );
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'success': return Icons.check_circle_outline;
      case 'warning': return Icons.warning_amber_rounded;
      case 'error': return Icons.error_outline;
      default: return Icons.info_outline;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'success': return Colors.green;
      case 'warning': return Colors.orange;
      case 'error': return Colors.red;
      default: return Colors.blue;
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${date.day}/${date.month}';
  }
}

class NotificationDetailScreen extends StatelessWidget {
  final AppNotification notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIcon(notification.type),
                  color: _getColor(notification.type),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    notification.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(notification.createdAt),
              style: const TextStyle(color: Colors.grey),
            ),
            const Divider(height: 32),
            Text(
              notification.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'success': return Icons.check_circle_outline;
      case 'warning': return Icons.warning_amber_rounded;
      case 'error': return Icons.error_outline;
      default: return Icons.info_outline;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'success': return Colors.green;
      case 'warning': return Colors.orange;
      case 'error': return Colors.red;
      default: return Colors.blue;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
class _AdNotificationTile extends StatelessWidget {
  final String title;
  final String concept;
  final String imageBase64;

  const _AdNotificationTile({required this.title, required this.concept, required this.imageBase64});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4F46E5);
    final imageBytes = _decodeBase64Safe(imageBase64);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryColor.withValues(alpha: 0.25), width: 1.2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageBytes != null
                ? Image.memory(
                    imageBytes,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : const Icon(Icons.star_rounded, color: primaryColor, size: 26),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'DESTACADO',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            concept,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _AdDetailScreen(title: title, concept: concept, imageBase64: imageBase64),
            ),
          );
        },
      ),
    );
  }
}

class _AdDetailScreen extends StatelessWidget {
  final String title;
  final String concept;
  final String imageBase64;

  const _AdDetailScreen({required this.title, required this.concept, required this.imageBase64});

  @override
  Widget build(BuildContext context) {
    final imageBytes = _decodeBase64Safe(imageBase64);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anuncio Destacado'),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  imageBytes,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Divider(height: 24),
            Text(
              concept,
              style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey.shade800),
            ),
          ],
        ),
      ),
    );
  }
}
