import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../modules/home/controllers/home_controller.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final GetStorage _storage = GetStorage();

  // Store the last notification count to detect new notifications
  int _lastNotificationCount = 0;

  Future<void> initialize() async {
    // Initialize settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // Initialize settings for iOS (no-op on Android-only builds)
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Initialize settings
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    // Initialize the plugin
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Load the last notification count
    _lastNotificationCount = _storage.read('lastNotificationCount') ?? 0;
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');

    try {
      if (Get.isRegistered<HomeController>()) {
        final homeController = Get.find<HomeController>();
        homeController.changeTab(3); // Navigate to notification tab (index 3)
      }
    } catch (e) {
      print('Error switching tab on notification tap: $e');
    }
  }

  Future<void> checkForNewNotifications(int currentNotificationCount) async {
    // Check if there are new notifications
    if (currentNotificationCount > _lastNotificationCount) {
      int newNotificationsCount =
          currentNotificationCount - _lastNotificationCount;

      // Show local notification for new notifications
      await _showNewNotificationsAlert(newNotificationsCount);

      // Update the stored count
      _lastNotificationCount = currentNotificationCount;
      await _storage.write('lastNotificationCount', currentNotificationCount);
    }
  }

  Future<void> _showNewNotificationsAlert(int count) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'new_notifications',
          'New Notifications',
          channelDescription: 'Notifications for new messages and updates',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'New Notifications',
      count == 1
          ? 'You have 1 new notification'
          : 'You have $count new notifications',
      platformChannelSpecifics,
      payload: 'notification_tab',
    );
  }

  Future<void> showCustomNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'custom_notifications',
          'Custom Notifications',
          channelDescription: 'Custom notifications from the app',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Method to reset notification count (useful when user visits notification tab)
  Future<void> resetNotificationCount(int currentCount) async {
    _lastNotificationCount = currentCount;
    await _storage.write('lastNotificationCount', currentCount);
  }
}
