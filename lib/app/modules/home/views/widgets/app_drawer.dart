import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../../../routes/app_routes.dart';
import '../../../auth/controllers/auth_controller.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../controllers/language_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  static const Color corporateBlue = Color(0xFF004A77);
  static const Color primaryGreen = Color(0xFF006E1C);
  static const Color errorColor = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void closeDrawer() {
      if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
        Scaffold.of(context).closeDrawer();
      } else {
        controller.zoomDrawerController.toggle?.call();
      }
    }
    
    // Premium theme colors
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: Container(
        color: bgColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Drawer Header
              _buildPremiumHeader(context, isDark, controller, textColor, iconColor, closeDrawer),
              
              const SizedBox(height: 10),
              
              // Navigation Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildPremiumNavItem(0, Icons.grid_view_rounded, 'home'.tr, controller, textColor, iconColor, closeDrawer),
                    _buildPremiumNavItem(1, Icons.fingerprint_rounded, 'attendance'.tr, controller, textColor, iconColor, closeDrawer),
                    _buildPremiumNavItem(2, Icons.account_circle_rounded, 'profile'.tr, controller, textColor, iconColor, closeDrawer),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Divider(height: 1, color: iconColor.withOpacity(0.15)),
                    ),
                    
                    _buildPremiumNavItem(4, Icons.settings_suggest_rounded, 'settings'.tr, controller, textColor, iconColor, closeDrawer),
                    
                    const SizedBox(height: 8),
                    // Language Toggle
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: corporateBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.language_rounded, color: corporateBlue, size: 22),
                      ),
                      title: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text('language'.tr,
                          maxLines: 1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: corporateBlue,
                          ),
                        ),
                      ),
                      trailing: Obx(() {
                        final isAr = Get.find<LanguageController>().currentLanguage.value == 'ar';
                        return Text(
                          isAr ? 'English' : 'العربية',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: corporateBlue),
                        );
                      }),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      onTap: () {
                        final langCtrl = Get.find<LanguageController>();
                        langCtrl.toggleLanguage();
                        Get.find<HomeController>().refreshAllData();
                      },
                    ),

                    // Logout
                    const SizedBox(height: 8),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.power_settings_new_rounded, color: errorColor, size: 22),
                      ),
                      title: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text('logout'.tr,
                          maxLines: 1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: errorColor,
                          ),
                        ),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      onTap: () async {
                        closeDrawer(); 
                        final shouldSignOut = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('sign_out'.tr),
                            content: Text('are_you_sure_sign_out'.tr),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    const SizedBox(height: 10),
                    Center(
                      child: FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final version = snapshot.data!.version;
                            return Text(
                              '${'version'.tr} $version',
                              style: TextStyle(
                                fontSize: 11,
                                color: iconColor.withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, bool isDark, HomeController controller, Color textColor, Color subTextColor, VoidCallback closeDrawer) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with premium ring
              Obx(() => Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  border: Border.all(color: primaryGreen, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.2),
                      blurRadius: 15, spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: controller.profilePictureUrl.value.isNotEmpty
                      ? Image.network(controller.profilePictureUrl.value, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.person, color: subTextColor, size: 35))
                      : Icon(Icons.person, color: subTextColor, size: 35),
                ),
              )),
              
              // Subtle close button
              IconButton(
                onPressed: closeDrawer,
                icon: Icon(Icons.close_rounded, color: subTextColor),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Obx(() => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              controller.employeeName.value.isNotEmpty ? controller.employeeName.value : 'Employee',
              maxLines: 1,
              style: GoogleFonts.outfit(
                color: textColor, fontSize: 24, fontWeight: FontWeight.w900,
                letterSpacing: -0.5, height: 1.1,
              ),
            ),
          )),
          const SizedBox(height: 6),
          Obx(() => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    controller.positionName.value.isNotEmpty ? controller.positionName.value : 'Position',
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      color: subTextColor, fontSize: 13, fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4, height: 4,
                decoration: BoxDecoration(color: subTextColor.withOpacity(0.5), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ID: ${controller.empNumber.value.isNotEmpty ? controller.empNumber.value : "N/A"}',
                  style: GoogleFonts.outfit(
                    color: primaryGreen, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildPremiumNavItem(int index, IconData icon, String label, HomeController controller, Color textColor, Color subTextColor, VoidCallback closeDrawer) {
    return Obx(() {
      final isSelected = controller.currentIndex.value == index;
      
      final activeColor = primaryGreen;
      final itemTextColor = isSelected ? activeColor : textColor;
      final itemIconColor = isSelected ? activeColor : subTextColor;
      final bgColor = isSelected ? activeColor.withOpacity(0.12) : Colors.transparent;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          selected: isSelected,
          tileColor: Colors.transparent,
          selectedTileColor: bgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? activeColor.withOpacity(0.1) : (Theme.of(Get.context!).brightness == Brightness.dark ? Colors.white10 : Colors.black.withOpacity(0.04)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: itemIconColor, size: 22),
          ),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(label,
              maxLines: 1,
              style: GoogleFonts.outfit(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15,
                color: itemTextColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
          onTap: () {
            closeDrawer();
            bool isSubPage = Get.currentRoute != AppRoutes.home && Get.currentRoute != '/';
            if (controller.currentIndex.value == index && !isSubPage) return;
            if (isSubPage) Get.until((route) => route.settings.name == AppRoutes.home || route.settings.name == '/');
            controller.changeTab(index);
          },
        ),
      );
    });
  }
}
