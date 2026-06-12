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
        // Menu icon (Right side)
        GestureDetector(
          onTap: onMenuTap ?? () {
            controller.zoomDrawerController.toggle?.call();
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? Colors.white.withOpacity(0.1) : surfaceBg,
              boxShadow: [
                BoxShadow(
                  color: corporateBlue.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            ),
            child: const Icon(Icons.grid_view_rounded, color: corporateBlue, size: 26),
          ),
        ),
      ],
    );
  }
}
