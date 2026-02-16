import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../app/session_controller.dart';
import '../models/notification.dart';

class NotificationsScreen extends StatefulWidget {
  final SessionController session;

  const NotificationsScreen({super.key, required this.session});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final List<dynamic> data = await widget.session.api.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = data.map((json) => AppNotification.fromJson(json)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load notifications.";
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.session.api.markAllRead();
      _fetchNotifications();
    } catch (_) {}
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await widget.session.api.markRead(notification.uid);
      _fetchNotifications();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.session.isDark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Notifications", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllRead,
              child: const Text("Mark all read"),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: subTextColor)))
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: subTextColor),
                            const SizedBox(height: 16),
                            Text("No notifications yet", style: TextStyle(color: subTextColor, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return _buildNotificationCard(notification, isDark, textColor, subTextColor);
                        },
                      ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification, bool isDark, Color textColor, Color? subTextColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => _markRead(notification),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getIconColor(notification.notificationType).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getIcon(notification.notificationType),
            color: _getIconColor(notification.notificationType),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.message, style: TextStyle(color: subTextColor)),
            const SizedBox(height: 8),
            Text(
              _formatTime(notification.createdAt),
              style: TextStyle(fontSize: 12, color: subTextColor?.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'ASSIGNMENT':
        return Icons.assignment_turned_in;
      case 'ALERT':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'ASSIGNMENT':
        return Colors.green;
      case 'ALERT':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${dt.day}/${dt.month}/${dt.year}";
  }
}
