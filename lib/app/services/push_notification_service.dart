import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../modules/home/controllers/home_controller.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in the background isolate
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');
  
  // Show standard notification for data-only payloads
  if (message.notification == null && message.data.isNotEmpty) {
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await localNotifications.initialize(initializationSettings);

    final title = message.data['title'] ?? message.data['NotifcnTitle'] ?? 'New Notification';
    final body = message.data['body'] ?? message.data['NotifcnBody'] ?? '';
    final notificationId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await localNotifications.show(
      notificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }
}

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // name
    description: 'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  // List of received notifications to display in NotificationTab
  static final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;

  Future<void> init() async {
    try {
      // Request permissions
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission for push notifications');
      }

      // Initialize Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/ic_notification');
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(initializationSettings);

      // Create Android Notification Channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Handle messages while app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleIncomingMessage(message);
      });

      // Handle messages when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Message clicked: ${message.messageId}');
        
        // Navigate to Notifications Tab
        if (Get.isRegistered<HomeController>()) {
          final homeController = Get.find<HomeController>();
          // Index 5 is the Notifications Tab in home_view.dart
          homeController.changeTab(5); 
          // Force a refresh of the notifications data
          homeController.fetchNotificationData();
        }
      });

      // Get FCM token
      String? token = await _fcm.getToken();
      debugPrint('FCM Token: $token');

    } catch (e) {
      debugPrint('Firebase initialization error (Push Notification Service): $e');
    }
  }

  void _handleIncomingMessage(RemoteMessage message) {
    debugPrint('Received a message while in the foreground!');
    
    // Add to HomeController if available
    try {
      if (Get.isRegistered<HomeController>()) {
        final homeController = Get.find<HomeController>();
        homeController.notifications.insert(0, {
          'NotifcnID': DateTime.now().millisecondsSinceEpoch.toString(),
          'NotifcnTitle': message.notification?.title ?? 'New Notification',
          'NotifcnBody': message.notification?.body ?? '',
          'NotifcnDate': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
          'ReadStatus': 'False',
          'IsRead': 0,
          'QueryString': message.data['QueryString'] ?? '',
        });
      }
    } catch (_) {}

    // Show Bubble (Snackbar) using GetX
    if (message.notification != null) {
      Get.snackbar(
        message.notification!.title ?? 'New Notification',
        message.notification!.body ?? '',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.brightness == Brightness.dark 
            ? const Color(0xFF1E293B) 
            : Colors.white,
        colorText: Get.theme.brightness == Brightness.dark 
            ? Colors.white 
            : Colors.black87,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        boxShadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        icon: const Icon(Icons.notifications_active, color: Color(0xFF10B981)),
      );
      
      // Also show the system-level banner in the top tray even when the app is open
      PushNotificationService.showLocalNotification(message);
    }
  }

  static void showLocalNotification(RemoteMessage message) {
    showLocalNotificationWithPlugin(message, _localNotifications);
  }

  static void showLocalNotificationWithPlugin(RemoteMessage message, FlutterLocalNotificationsPlugin plugin) {
    // Determine title and body from notification payload or data payload
    final title = message.notification?.title ?? message.data['title'] ?? message.data['NotifcnTitle'] ?? 'New Notification';
    final body = message.notification?.body ?? message.data['body'] ?? message.data['NotifcnBody'] ?? '';
    
    // Create a safe, unique integer ID (messageId hashCode can be null/empty)
    final notificationId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }
}
