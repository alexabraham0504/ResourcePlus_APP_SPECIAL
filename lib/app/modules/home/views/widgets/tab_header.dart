import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../../../controllers/language_controller.dart';
import '../../../auth/controllers/auth_controller.dart' as resource_plus_auth;
import '../../../../routes/app_routes.dart';
import '../../../../controllers/global_beacon_controller.dart';

/// Shared hamburger menu header for all tabs
class TabHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationTap;
  const TabHeader({super.key, required this.title, this.onMenuTap, this.onNotificationTap});

  static const Color corporateBlue = Color(0xFF004A77);
  static const Color primaryGreen = Color(0xFF006E1C);
  static const Color onSurfaceVariant = Color(0xFF3F4A3C);
  static const Color secondaryOrange = Color(0xFF934B00);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceBg = const Color(0xFFF9F9FC);

    return Row(
      children: [
        // Logo (Left side)
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
        // Action icons (Right side)
        Row(
          children: [
            // Notification Bell
            GestureDetector(
              onTap: () {
                if (onNotificationTap != null) {
                  onNotificationTap!();
                } else {
                  controller.changeTab(5);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : surfaceBg,
                  boxShadow: [
                    BoxShadow(
                      color: corporateBlue.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                ),
                child: Obx(() {
                  final btController = Get.find<GlobalBeaconController>();
                  final btColor = btController.activeBeaconColor.value;
                  
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bluetooth active indicator
                      if (btColor != null) ...[
                        GestureDetector(
                          onTap: () => btController.showBeaconDetails(),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.bluetooth_connected, color: btColor, size: 24),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 1,
                          height: 20,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Notification bell
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_none_rounded, color: corporateBlue, size: 24),
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: controller.unreadNotificationsCount > 0 ? Colors.red : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                controller.unreadNotificationsCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            // Language Toggle
            GestureDetector(
              onTap: () {
                final langController = Get.find<LanguageController>();
                langController.toggleLanguage();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : surfaceBg,
                  boxShadow: [
                    BoxShadow(
                      color: corporateBlue.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                ),
                child: Obx(() {
                  final langController = Get.find<LanguageController>();
                  // Show the target language that the user will switch to when tapping
                  final langText = langController.currentLanguage.value == 'en' ? 'AR' : 'EN';
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_rounded, color: corporateBlue, size: 22),
                      const SizedBox(width: 4),
                      Text(langText, style: const TextStyle(color: corporateBlue, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            // Logout Button
            GestureDetector(
              onTap: () {
                final langController = Get.find<LanguageController>();
                final isAr = langController.currentLanguage.value == 'ar';
                
                Get.defaultDialog(
                  title: isAr ? 'تسجيل خروج' : 'Logout',
                  middleText: isAr ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟' : 'Are you sure you want to log out?',
                  textConfirm: isAr ? 'نعم' : 'Yes',
                  textCancel: isAr ? 'إلغاء' : 'Cancel',
                  confirmTextColor: Colors.white,
                  cancelTextColor: Colors.red,
                  buttonColor: Colors.red,
                  onConfirm: () {
                    // Find auth controller and logout
                    try {
                      final authController = Get.find<resource_plus_auth.AuthController>();
                      authController.logout();
                      Get.offAllNamed(AppRoutes.login);
                    } catch (e) {
                      // Fallback if not found in current scope
                      Get.offAllNamed(AppRoutes.login);
                    }
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : surfaceBg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                ),
                child: const Icon(Icons.power_settings_new_rounded, color: Colors.red, size: 26),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
