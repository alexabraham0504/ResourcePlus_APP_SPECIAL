import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../../../routes/app_routes.dart';
import '../../../auth/controllers/auth_controller.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  static const Color corporateBlue = Color(0xFF004A77);
  static const Color primaryGreen = Color(0xFF006E1C);
  static const Color errorColor = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF121212) : const Color(0xFF004A77),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            _buildDrawerHeader(context, isDark, controller),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                children: [
                  _buildNavItem(context, isDark, 0, Icons.grid_view, 'home'.tr, primaryGreen, controller),
                  _buildNavItem(context, isDark, 1, Icons.fingerprint, 'attendance'.tr, corporateBlue, controller),
                  _buildNavItem(context, isDark, 2, Icons.account_circle, 'profile'.tr, const Color(0xFFFC943B), controller),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Divider(height: 1),
                  ),
                  _buildNavItem(context, isDark, 4, Icons.settings_suggest, 'settings'.tr, const Color(0xFF6F7A6B), controller),
                  
                  // Logout
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      leading: Icon(Icons.power_settings_new, color: errorColor),
                      title: Text('logout'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: errorColor,
                        ),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onTap: () async {
                        Navigator.pop(context); // Close Drawer
                        final shouldSignOut = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('sign_out'.tr),
                            content: Text('are_you_sure_sign_out'.tr),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('cancel'.tr)),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(backgroundColor: errorColor, foregroundColor: Colors.white),
                                child: Text('sign_out'.tr),
                              ),
                            ],
                          ),
                        );
                        if (shouldSignOut == true) {
                          try {
                            final auth = Get.find<AuthController>();
                            await auth.logout();
                          } catch (e) {}
                          Get.offAllNamed(AppRoutes.login);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, bool isDark, HomeController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [corporateBlue, primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(topRight: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Obx(() => Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: controller.profilePictureUrl.value.isNotEmpty
                      ? Image.network(controller.profilePictureUrl.value,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, color: Colors.white, size: 30))
                      : const Icon(Icons.person, color: Colors.white, size: 30),
                ),
              )),
              const Spacer(),
              // Close button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() => Text(
            controller.employeeName.value.isNotEmpty
                ? controller.employeeName.value : 'Employee',
            style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          )),
          const SizedBox(height: 4),
          Obx(() => Row(
            children: [
              Text(
                controller.positionName.value.isNotEmpty
                    ? controller.positionName.value : 'Position',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12, fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 4, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Text(
                'ID:${controller.empNumber.value.isNotEmpty ? controller.empNumber.value : "N/A"}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12, fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, bool isDark, int index, IconData icon, String label, Color iconColor, HomeController controller, {int badgeCount = 0}) {
    return Obx(() {
      final isSelected = controller.currentIndex.value == index;

      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          selected: isSelected,
          selectedTileColor: primaryGreen.withOpacity(isDark ? 0.2 : 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isSelected
                ? BorderSide(color: primaryGreen.withOpacity(0.1))
                : BorderSide.none,
          ),
          leading: badgeCount > 0
              ? Badge(
                  label: Text('$badgeCount', style: const TextStyle(fontSize: 10)),
                  child: Icon(icon, color: isSelected ? primaryGreen : iconColor),
                )
              : Icon(icon, color: isSelected ? primaryGreen : iconColor),
          title: Text(label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: Colors.white,
            ),
          ),
          onTap: () {
            final zoomDrawer = Get.find<HomeController>().zoomDrawerController;
            zoomDrawer.toggle?.call();
            
            bool isSubPage = Get.currentRoute != AppRoutes.home && Get.currentRoute != '/';

            // If already on the same tab and we are on HomeView, do nothing
            if (controller.currentIndex.value == index && !isSubPage) return;
            
            // Pop the current page if it is a sub-page (like hr_portal or attendance_history)
            if (isSubPage) {
              Get.until((route) => route.settings.name == AppRoutes.home || route.settings.name == '/');
            }
            
            controller.changeTab(index);
          },
        ),
      );
    });
  }
}
