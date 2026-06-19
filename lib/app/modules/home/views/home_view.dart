import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import 'tabs/home_tab.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/notification_tab.dart';
import 'tabs/settings_tab.dart';
import 'package:resource_plus/app/routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import 'widgets/app_drawer.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({Key? key}) : super(key: key);

  // Design system colors
  static const Color corporateBlue = Color(0xFF004A77);
  static const Color primaryGreen = Color(0xFF006E1C);
  static const Color errorColor = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final isHomeTab = controller.currentIndex.value == 0;
      
      return PopScope(
        canPop: isHomeTab,
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (controller.zoomDrawerController.isOpen?.call() ?? false) {
            controller.zoomDrawerController.close?.call();
            return;
          }
          if (!isHomeTab) {
            controller.changeTab(0);
          }
        },
        child: ZoomDrawer(
          controller: controller.zoomDrawerController,
          menuScreen: AppDrawer(onClose: () => controller.zoomDrawerController.toggle?.call()),
          mainScreen: Scaffold(
            key: controller.scaffoldKey,
            floatingActionButton: controller.currentIndex.value == 1
                ? PulsingPunchFab(
                    onPressed: () => Get.toNamed(AppRoutes.hrPortal),
                  )
                : null,
            // No bottom navigation bar - tabs are in the drawer now
            body: () {
              switch (controller.currentIndex.value) {
                case 0:
                  return const HomeTab();
                case 1:
                  return const AttendanceTab();
                case 2:
                  return const ProfileTab();
                case 4:
                  return const SettingsTab();
                default:
                  return const HomeTab();
              }
            }(),
          ),
          borderRadius: 24.0,
          showShadow: true,
          angle: -10.0,
          isRtl: true, // This moves the menu to the right side
          drawerShadowsBackgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
          slideWidth: MediaQuery.of(context).size.width * 0.65,
          openCurve: Curves.easeOutCubic,
          closeCurve: Curves.easeOutQuint,
          duration: const Duration(milliseconds: 450),
        ),
      );
    });
  }
}

class PulsingPunchFab extends StatefulWidget {
  final VoidCallback onPressed;
  const PulsingPunchFab({Key? key, required this.onPressed}) : super(key: key);

  @override
  State<PulsingPunchFab> createState() => _PulsingPunchFabState();
}

class _PulsingPunchFabState extends State<PulsingPunchFab> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1, milliseconds: 200));
    _animation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004A77).withOpacity(0.4 * _animation.value),
                  blurRadius: 15 * _animation.value,
                  spreadRadius: 2 * _animation.value,
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: widget.onPressed,
              backgroundColor: const Color(0xFF004A77), // Corporate Blue instead of green
              elevation: 0, // Elevation handled by custom shadow
              child: const Icon(Icons.access_time, color: Colors.white, size: 30),
            ),
          ),
        );
      },
    );
  }
}
