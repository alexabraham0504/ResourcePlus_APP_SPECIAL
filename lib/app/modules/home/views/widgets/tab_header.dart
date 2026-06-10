import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';

/// Shared hamburger menu header for all tabs
class TabHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationTap;
  const TabHeader({Key? key, required this.title, this.onMenuTap, this.onNotificationTap}) : super(key: key);

  static const Color corporateBlue = Color(0xFF004A77);
  static const Color primaryGreen = Color(0xFF006E1C);
  static const Color onSurfaceVariant = Color(0xFF3F4A3C);
  static const Color secondaryOrange = Color(0xFF934B00);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Hamburger menu
        GestureDetector(
          onTap: onMenuTap ?? () {
            if (Scaffold.of(context).hasDrawer) {
              Scaffold.of(context).openDrawer();
            } else {
              controller.scaffoldKey.currentState?.openDrawer();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu, color: corporateBlue, size: 26),
          ),
        ),
        const SizedBox(width: 12),
        // Logo
        Image.asset(
          'assets/app_logo.png',
          height: 22,
          errorBuilder: (_, __, ___) => Text('ResourcePlus',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800,
              foreground: Paint()..shader = const LinearGradient(
                colors: [corporateBlue, primaryGreen],
              ).createShader(const Rect.fromLTWH(0, 0, 200, 24)),
            ),
          ),
        ),
        const Spacer(),
        // Notification bell
        GestureDetector(
          onTap: onNotificationTap ?? () => controller.changeTab(3),
          child: Obx(() => Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4.0, right: 4.0),
                child: Icon(Icons.notifications_outlined,
                  color: isDark ? Colors.white70 : onSurfaceVariant, size: 28),
              ),
              if (controller.unreadNotificationsCount > 0)
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF121212) : const Color(0xFFF9F9FC),
                        width: 1.5,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        controller.unreadNotificationsCount > 99 
                            ? '99+' 
                            : controller.unreadNotificationsCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          )),
        ),
      ],
    );
  }
}
