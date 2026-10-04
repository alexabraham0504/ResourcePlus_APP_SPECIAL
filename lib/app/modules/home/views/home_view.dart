import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import 'tabs/home_tab.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/self_service_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/notification_tab.dart' as resource_plus_notifications;
import 'tabs/ai_chat_tab.dart';
import 'tabs/ai_workforce_tab.dart';
import 'widgets/global_expandable_fab.dart';
import 'widgets/home_bottom_navigation.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  // Design system colors
  static const Color corporateBlue = Color(0xFF004A77);
  static const Color primaryGreen = Color(0xFF006E1C);
  static const Color errorColor = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isHomeTab = controller.currentIndex.value == 0;
      
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (!isHomeTab) {
            controller.changeTab(0);
          } else {
            // If on home tab and user presses back, exit the app properly
            SystemNavigator.pop();
          }
        },
        child: GlobalExpandableFab(
          isVisible: controller.currentIndex.value != 6 && 
                     controller.currentIndex.value != 7,
          child: Scaffold(
            key: controller.scaffoldKey,
            body: IndexedStack(
              index: controller.currentIndex.value > 7 ? 0 : controller.currentIndex.value,
              children: const [
                HomeTab(),
                LazyTab(index: 1, child: AttendanceTab()),
                SelfServiceTab(), // SelfServiceTab handles its own laziness internally
                LazyTab(index: 3, child: ProfileTab()),
                LazyTab(index: 4, child: SettingsTab()),
                LazyTab(index: 5, child: resource_plus_notifications.NotificationTab()),
                LazyTab(index: 6, child: AIChatTab()),
                LazyTab(index: 7, child: AiWorkforceTab()),
              ],
            ),
            bottomNavigationBar: HomeBottomNavigation(
              currentIndex: controller.currentIndex.value,
              onTap: controller.changeTab,
            ),
          ),
        ),
      );
    });
  }
}

class PulsingPunchFab extends StatefulWidget {
  final VoidCallback onPressed;
  const PulsingPunchFab({super.key, required this.onPressed});

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
                  color: const Color(0xFF004A77).withValues(alpha: 0.4 * _animation.value),
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

class LazyTab extends StatefulWidget {
  final Widget child;
  final int index;
  const LazyTab({super.key, required this.child, required this.index});

  @override
  State<LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<LazyTab> {
  final controller = Get.find<HomeController>();
  bool _hasBeenActivated = false;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.currentIndex.value == widget.index) {
        _hasBeenActivated = true;
      }
      if (!_hasBeenActivated) {
        return const SizedBox.shrink();
      }
      return widget.child;
    });
  }
}
