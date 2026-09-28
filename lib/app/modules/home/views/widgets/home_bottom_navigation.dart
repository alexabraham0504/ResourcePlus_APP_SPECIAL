import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The shared home-shell navigation, also used by full-screen previews.
class HomeBottomNavigation extends StatelessWidget {
  const HomeBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark ? Colors.grey[500] : Colors.grey[400];
    final isPrimaryTab = currentIndex >= 0 && currentIndex <= 4;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .3 : .05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: isPrimaryTab ? currentIndex : 0,
        onTap: onTap,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedItemColor: isPrimaryTab
            ? const [
                Color(0xFF004A77),
                Color(0xFF006E1C),
                Color(0xFF8B5CF6),
                Color(0xFFFC943B),
                Color(0xFF6F7A6B),
              ][currentIndex]
            : inactive,
        unselectedItemColor: inactive,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_rounded),
            label: 'home'.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_month_rounded),
            label: 'attendance'.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.widgets_rounded),
            label: 'self_service'.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_rounded),
            label: 'profile'.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_rounded),
            label: 'settings'.tr,
          ),
        ],
      ),
    );
  }
}
