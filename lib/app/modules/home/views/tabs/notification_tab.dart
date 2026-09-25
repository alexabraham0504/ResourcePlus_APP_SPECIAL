import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../../../services/notification_service.dart';
import '../widgets/tab_header.dart';
import '../webview_page.dart' as resource_plus_webview;

class NotificationTab extends StatelessWidget {
  const NotificationTab({super.key});

  // ─── Professional Corporate Palette ──────────────────────────────
  static const _primary = Color(0xFF0F172A); // Slate 900
  static const _surface = Colors.white;
  static const _bg = Color(0xFFF8FAFC); // Slate 50
  static const _accent = Color(0xFF004A77); // Corporate Blue
  static const _accentLight = Color(0xFFE0F2FE); // Sky 100
  static const _unreadColor = Color(0xFF059669); // Emerald 600

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final notificationService = NotificationService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : _bg;

    // Reset notification count when user visits notification tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notificationService.resetNotificationCount(
        controller.notifications.length,
      );
    });

    return Scaffold(
      backgroundColor: bgColor,
      body: Obx(() {
        if (controller.isNotificationLoading.value) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }

        if (controller.hasNotificationError.value) {
          return _buildErrorState(context, controller);
        }

        return SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  children: [
                    const TabHeader(title: 'Notifications'), // Uses API/static translation in TabHeader if needed, but title prop isn't actually used by TabHeader's UI since it uses the logo.
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'recent_activity'.tr,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : _primary,
                          ),
                        ),
                        if (controller.notifications.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _markAllAsRead(controller),
                            icon: const Icon(Icons.done_all_rounded, size: 18),
                            label: Text(
                              controller.notificationStaticContents['MarkAllText'] ?? 'mark_all_read'.tr,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? Colors.grey[300] : _primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Notifications List
              Expanded(
                child: controller.notifications.isEmpty
                    ? _buildEmptyState(isDark)
                    : RefreshIndicator(
                        onRefresh: controller.fetchNotificationData,
                        color: _primary,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: controller.notifications.length,
                          itemBuilder: (context, index) {
                            return _buildNotificationItem(context, controller, index, isDark);
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  INDIVIDUAL NOTIFICATION CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildNotificationItem(BuildContext context, HomeController controller, int index, bool isDark) {
    final notification = controller.notifications[index];
    final readStatusValue = notification['ReadStatus'] ?? notification['IsRead'] ?? notification['isRead'];
    final isRead = readStatusValue == 'True' || readStatusValue == 'true' || readStatusValue == 1 || readStatusValue == true;

    final cardBg = isDark ? const Color(0xFF1E293B) : _surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isRead ? cardBg : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF2F8FF)), // Distinct light blue for unread
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isRead ? borderColor : Colors.blue[400]!, width: isRead ? 1 : 1.5),
          boxShadow: [
            if (!isDark && !isRead)
              BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
            if (!isDark && isRead)
              BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _handleNotificationTap(controller, notification, isRead),
            child: Stack(
              children: [
                if (!isRead)
                  Positioned(
                    left: 0,
                    top: 16,
                    bottom: 16,
                    child: Container(
                      width: 4,
                      decoration: const BoxDecoration(
                        color: _unreadColor,
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isRead
                              ? (isDark ? Colors.white.withValues(alpha: 0.05) : _bg)
                              : _unreadColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                          color: isRead ? (isDark ? Colors.grey[400] : Colors.grey[500]) : _unreadColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    notification['NotifcnTitle'] ?? 'Notification',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                      color: isDark ? Colors.white : _primary,
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[600],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notification['NotifcnBody'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 12, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  notification['NotifcnDate'] ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STATE UI HELPERS
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 600),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  if (!isDark) BoxShadow(color: _primary.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              'no_notifications'.tr,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : _primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'all_caught_up'.tr,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, HomeController controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('error_loading_notifications'.tr,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: controller.refreshNotificationData,
            icon: const Icon(Icons.refresh),
            label: Text('retry'.tr),
            style: TextButton.styleFrom(foregroundColor: _primary),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  LOGIC HELPERS
  // ═══════════════════════════════════════════════════════════
  void _handleNotificationTap(HomeController controller, Map<String, dynamic> notification, bool isRead) async {
    final baseUrl = controller.commonContents['BaseUrl'] ?? '';
    final queryString = notification['QueryString']?.toString() ?? '';

    if (queryString.isNotEmpty) {
      String fullUrl = (queryString.startsWith('http://') || queryString.startsWith('https://'))
          ? queryString
          : (baseUrl + queryString);
      
      // Fix case-sensitivity: server requires 'NSPApp' (uppercase) not 'nspApp'
      fullUrl = fullUrl
          .replaceAll('/nspApp/', '/NSPApp/')
          .replaceAll('/nspapp/', '/NSPApp/');

      try {
        final notificationTitle = notification['NotifcnTitle'] ?? 'Notification';
        
        Get.to(() => resource_plus_webview.WebViewPage(
          url: fullUrl,
          title: notificationTitle.toString(),
        ));

        if (!isRead) _markSingleAsRead(controller, notification);
      } catch (e) {
        Get.snackbar('Error', 'Failed to open URL: $e', backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      }
    } else {
      if (!isRead) _markSingleAsRead(controller, notification);
    }
  }

  void _markSingleAsRead(HomeController controller, Map<String, dynamic> notification) {
    final notificationId = int.tryParse(notification['NotifcnID'].toString()) ?? 0;
    
    // Optimistically update local state immediately
    final currentIndex = controller.notifications.indexWhere(
      (n) => (int.tryParse(n['NotifcnID'].toString()) ?? 0) == notificationId,
    );
    
    if (currentIndex >= 0) {
      controller.notifications[currentIndex] = Map<String, dynamic>.from(controller.notifications[currentIndex])
        ..['ReadStatus'] = 'True'
        ..['IsRead'] = 1
        ..['isRead'] = 1;
    }

    // Update backend
    controller.updateNotificationReadStatus(notificationId, 1);
  }

  void _markAllAsRead(HomeController controller) async {
    try {
      final unreadNotificationIds = <int>[];

      for (var i = 0; i < controller.notifications.length; i++) {
        final notification = controller.notifications[i];
        final readStatusValue = notification['ReadStatus'] ?? notification['IsRead'] ?? notification['isRead'];
        final isRead = readStatusValue == 'True' || readStatusValue == 'true' || readStatusValue == 1 || readStatusValue == true;

        if (!isRead) {
          final notificationId = int.tryParse(notification['NotifcnID'].toString()) ?? 0;
          if (notificationId > 0) {
            unreadNotificationIds.add(notificationId);
            controller.notifications[i] = Map<String, dynamic>.from(notification)
              ..['ReadStatus'] = 'True'
              ..['IsRead'] = 1
              ..['isRead'] = 1;
          }
        }
      }

      Get.snackbar(
        'Success',
        'All notifications marked as read',
        backgroundColor: _unreadColor,
        colorText: Colors.white,
      );

      for (final notificationId in unreadNotificationIds) {
        try {
          await controller.updateNotificationReadStatus(notificationId, 1, refreshAfterUpdate: false);
        } catch (e) {
          debugPrint('Error updating notification $notificationId: $e');
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
      await controller.fetchNotificationData();
    } catch (e) {
      await controller.fetchNotificationData();
      Get.snackbar('Error', 'Failed to mark notifications as read', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }
}
