import 'package:get_storage/get_storage.dart';

/// Notification service — all methods are no-ops.
/// Push notifications and local notifications have been fully disabled
/// for this release. The class skeleton remains so call-sites don't break.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// No-op: notifications are disabled.
  Future<void> initialize() async {
    // Notifications fully disabled for this release.
  }

  /// No-op: notifications are disabled.
  Future<void> checkForNewNotifications(int currentNotificationCount) async {
    // Notifications fully disabled.
  }

  /// No-op: notifications are disabled.
  Future<void> showCustomNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Notifications fully disabled.
  }

  /// No-op: notifications are disabled.
  Future<void> cancelAllNotifications() async {}

  /// No-op: notifications are disabled.
  Future<void> cancelNotification(int id) async {}

  /// No-op: notifications are disabled.
  Future<void> resetNotificationCount(int currentCount) async {}
}
