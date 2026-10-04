import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../routes/app_routes.dart';
import '../../controllers/home_controller.dart';
import '../../../../controllers/theme_controller.dart';
import '../../../../controllers/language_controller.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../widgets/tab_header.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  // ─── Professional Corporate Palette ──────────────────────────────
  static const _primary = Color(0xFF0F172A); // Slate 900
  static const _surface = Colors.white;
  static const _bg = Color(0xFFF8FAFC); // Slate 50
  static const _error = Color(0xFFDC2626); // Red 600

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final themeController = Get.find<ThemeController>();
    final languageController = Get.find<LanguageController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : _bg;

    return Scaffold(
      backgroundColor: bgColor,
      body: Obx(() {
        if (controller.isSettingsLoading.value) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }

        if (controller.hasSettingsError.value) {
          return _buildErrorState(context, controller);
        }

        return SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: TabHeader(title: 'Settings'),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.fetchSettingsData,
                  color: _primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildSettingsSection(
                          context: context,
                          title: controller.settingsStaticContents['PreferencesText'] ?? 'Preferences',
                          index: 0,
                          items: [
                            Obx(() => _buildSettingsItem(
                              context: context,
                              icon: Icons.language_rounded,
                              title: controller.settingsStaticContents['LanguageText'] ?? 'Language',
                              subtitle: 'choose_language'.tr,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    Get.locale?.languageCode == 'ar' ? 'English' : 'العربية',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : _primary),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                                ],
                              ),
                              onTap: () => _showLanguageDialog(context, languageController),
                            )),
                            _buildSettingsItem(
                              context: context,
                              icon: Icons.dark_mode_rounded,
                              title: controller.settingsStaticContents['DarkModeText'] ?? 'Dark Mode',
                              subtitle: 'switch_theme'.tr,
                              trailing: Obx(() => Switch(
                                value: themeController.isDarkMode.value,
                                onChanged: (value) => themeController.toggleTheme(),
                                activeThumbColor: isDark ? Colors.white : _primary,
                                activeTrackColor: isDark ? _primary : Colors.grey[300],
                              )),
                              onTap: null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSettingsSection(
                          context: context,
                          title: controller.settingsStaticContents['SecurityText'] ?? 'Security',
                          index: 1,
                          items: [
                            _buildSettingsItem(
                              context: context,
                              icon: Icons.lock_outline_rounded,
                              title: controller.settingsStaticContents['ChangePasswordText'] ?? 'Change Password',
                              subtitle: 'update_password'.tr,
                              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                              onTap: () => _showChangePasswordDialog(context),
                            ),
                            _buildSettingsItem(
                              context: context,
                              icon: Icons.description_outlined,
                              title: 'privacy_terms'.tr,
                              subtitle: 'read_privacy_terms'.tr,
                              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                              onTap: () => _showPrivacyTermsBottomSheet(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSettingsSection(
                          context: context,
                          title: controller.settingsStaticContents['SupportText'] ?? 'Support',
                          index: 2,
                          items: [
                            _buildSettingsItem(
                              context: context,
                              icon: Icons.help_outline_rounded,
                              title: controller.settingsStaticContents['HelpAndSupportText'] ?? 'Help & Support',
                              subtitle: 'get_help'.tr,
                              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                              onTap: () async => await _openSupportURL(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSettingsSection(
                          context: context,
                          title: 'account'.tr,
                          index: 3,
                          items: [
                            _buildSettingsItem(
                              context: context,
                              icon: Icons.logout_rounded,
                              title: controller.settingsStaticContents['SignOutText'] ?? 'Sign out',
                              subtitle: 'sign_out_account'.tr,
                              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _error),
                              isDestructive: true,
                              onTap: () async {
                                final shouldSignOut = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('sign_out'.tr),
                                    content: Text('are_you_sure_sign_out'.tr),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('cancel'.tr)),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        style: ElevatedButton.styleFrom(backgroundColor: _error, foregroundColor: Colors.white),
                                        child: Text('sign_out'.tr),
                                      ),
                                    ],
                                  ),
                                );
                                if (shouldSignOut == true) {
                                  await Get.put(AuthController()).logout();
                                  Get.offAllNamed(AppRoutes.login);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Center(
                          child: FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final version = snapshot.data!.version;
                                return Text(
                                  'ResourcePlus™ • Demo Version $version',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.1,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildErrorState(BuildContext context, HomeController controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('error_loading_settings'.tr,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: controller.refreshSettingsData,
            icon: const Icon(Icons.refresh),
            label: Text('retry'.tr),
            style: TextButton.styleFrom(foregroundColor: _primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required BuildContext context,
    required String title,
    required int index,
    required List<Widget> items,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : _surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 150)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [
                if (!isDark)
                  BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? _error.withValues(alpha: 0.1)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : _bg),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? _error : (isDark ? Colors.grey[300] : _primary),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? _error : (isDark ? Colors.white : _primary),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    LanguageController languageController,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('language'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                trailing: languageController.currentLanguage.value == LanguageController.english 
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) 
                  : null,
                onTap: () {
                  languageController.changeLanguage(LanguageController.english);
                  Navigator.of(context).pop();
                  Get.find<HomeController>().refreshAllData();
                },
              ),
              ListTile(
                title: const Text('العربية'),
                trailing: languageController.currentLanguage.value == LanguageController.arabic 
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) 
                  : null,
                onTap: () {
                  languageController.changeLanguage(LanguageController.arabic);
                  Navigator.of(context).pop();
                  Get.find<HomeController>().refreshAllData();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('cancel'.tr),
            ),
          ],
        );
      },
    );
  }

  void _showNotificationSettings(BuildContext context) {
    final controller = Get.find<HomeController>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Obx(
              () => AlertDialog(
                title: Text('notifications_settings'.tr),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Live Notifications Toggle
                      ListTile(
                        title: Text('live_notifications'.tr),
                        subtitle: Text(
                          'Automatically check for new notifications',
                        ),
                        trailing: Switch(
                          value: controller.isPollingEnabled.value,
                          onChanged: (value) {
                            if (value) {
                              controller.enableNotificationPolling();
                            } else {
                              controller.disableNotificationPolling();
                            }
                          },
                        ),
                      ),

                      // Polling Interval
                      if (controller.isPollingEnabled.value) ...[
                        ListTile(
                          title: Text('check_interval'.tr),
                          subtitle: Text(
                            'How often to check for new notifications',
                          ),
                          trailing: DropdownButton<int>(
                            value: controller.pollingIntervalMinutes.value,
                            items: [1, 2, 5, 10, 15, 30].map((minutes) {
                              return DropdownMenuItem<int>(
                                value: minutes,
                                child: Text(
                                  '$minutes min${minutes == 1 ? '' : 's'}',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                controller.updatePollingInterval(value);
                              }
                            },
                          ),
                        ),

                        // Polling Status
                        ListTile(
                          title: Text('status'.tr),
                          subtitle: Text(
                            controller.isPollingActive.value
                                ? 'Active - Checking every ${controller.pollingIntervalMinutes.value} minutes'
                                : 'Inactive',
                          ),
                          trailing: Icon(
                            controller.isPollingActive.value
                                ? Icons.check_circle
                                : Icons.pause_circle,
                            color: controller.isPollingActive.value
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),

                        // Force Check Button
                        ListTile(
                          title: Text('check_now'.tr),
                          subtitle: Text(
                            'Manually check for new notifications',
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.refresh),
                            onPressed: () {
                              controller.forceNotificationCheck();
                              Get.snackbar(
                                'Checking',
                                'Checking for new notifications...',
                                backgroundColor: Colors.blue,
                                colorText: Colors.white,
                              );
                            },
                          ),
                        ),
                      ],

                      const Divider(),

                      // Push Notifications
                      ListTile(
                        title: Text('push_notifications'.tr),
                        subtitle: Text(
                          'Show local notifications for new messages',
                        ),
                        trailing: Switch(
                          value: controller.pushNotificationsEnabled.value,
                          onChanged: (value) {
                            if (value) {
                              controller.enablePushNotifications();
                            } else {
                              controller.disablePushNotifications();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('close'.tr),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const _ChangePasswordDialogContent();
      },
    );
  }

  void _showPrivacySettings(BuildContext context) {
    final storage = GetStorage();
    bool dataCollection = storage.read('privacy_data_collection') ?? false;
    bool analytics = storage.read('privacy_analytics') ?? true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('privacy_settings'.tr),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('data_collection'.tr),
                    subtitle: Text('allow_usage_data'.tr),
                    trailing: Switch(
                      value: dataCollection,
                      onChanged: (value) {
                        setState(() {
                          dataCollection = value;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: Text('analytics'.tr),
                    subtitle: Text('share_anonymous_stats'.tr),
                    trailing: Switch(
                      value: analytics,
                      onChanged: (value) {
                        setState(() {
                          analytics = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('cancel'.tr),
                ),
                ElevatedButton(
                  onPressed: () {
                    storage.write('privacy_data_collection', dataCollection);
                    storage.write('privacy_analytics', analytics);
                    Navigator.of(context).pop();
                    Get.snackbar(
                      'Success',
                      'Privacy settings updated',
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  },
                  child: Text('save'.tr),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPrivacyTermsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'privacy_terms'.tr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.privacy_tip_outlined, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text('privacy_policy'.tr),
                  subtitle: Text('privacy_policy_subtitle'.tr),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).pop();
                    Get.toNamed(AppRoutes.privacyTermsDetail, arguments: 'privacy');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text('terms_conditions'.tr),
                  subtitle: Text('terms_conditions_subtitle'.tr),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).pop();
                    Get.toNamed(AppRoutes.privacyTermsDetail, arguments: 'terms');
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSupportURL() async {
    final controller = Get.find<HomeController>();
    final String titleText = controller
            .settingsStaticContents['HelpAndSupportText'] ??
        'Help & Support';

    /*
    // Previous logic (commented but preserved as requested)
    try {
      // Fetch support URL from API (without loading dialog)
      final supportURL = await controller.getSupportURL();

      String urlToOpen;
      if (supportURL != null && supportURL.isNotEmpty) {
        urlToOpen = supportURL;
      } else {
        // Fallback to default support URL if API fails
        urlToOpen = 'https://resourceplus.app/contact-us/';
      }

      // Open URL in in-app WebView
      Get.toNamed(
        AppRoutes.webview,
        parameters: {
          'url': urlToOpen,
          'title': titleText,
        },
      );
    } catch (e) {
      // Fallback to default URL if error occurs
      Get.toNamed(
        AppRoutes.webview,
        parameters: {
          'url': 'https://resourceplus.app/contact-us/',
          'title': titleText,
        },
      );
    }
    */

    // Redirect to the new support link as requested
    Get.toNamed(
      AppRoutes.webview,
      preventDuplicates: true,
      parameters: {
        'url': 'https://portalug.resourceplusonline.com',
        'title': titleText,
      },
    );
  }

}

class _ChangePasswordDialogContent extends StatefulWidget {
  const _ChangePasswordDialogContent();

  @override
  State<_ChangePasswordDialogContent> createState() => _ChangePasswordDialogContentState();
}

class _ChangePasswordDialogContentState extends State<_ChangePasswordDialogContent> {
  late TextEditingController currentPasswordController;
  late TextEditingController newPasswordController;
  late TextEditingController confirmPasswordController;
  late AuthController authController;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    currentPasswordController = TextEditingController();
    newPasswordController = TextEditingController();
    confirmPasswordController = TextEditingController();
    authController = Get.put(AuthController());
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AlertDialog(
        title: Text('change_password'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              enabled: !authController.isLoading.value,
              decoration: InputDecoration(
                labelText: 'current_password'.tr,
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              enabled: !authController.isLoading.value,
              decoration: InputDecoration(
                labelText: 'new_password'.tr,
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              enabled: !authController.isLoading.value,
              decoration: InputDecoration(
                labelText: 'confirm_password'.tr,
                border: OutlineInputBorder(),
              ),
            ),
            if (errorMessage != null) ...[
              SizedBox(height: 16),
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: authController.isLoading.value
                ? null
                : () => Navigator.of(context).pop(),
            child: Text('cancel'.tr),
          ),
          authController.isLoading.value
              ? CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: () async {
                    setState(() { errorMessage = null; });
                    final currentPassword = currentPasswordController.text.trim();
                    final newPassword = newPasswordController.text.trim();
                    final confirmPassword = confirmPasswordController.text.trim();
                    final currentContext = context;

                    if (currentPassword.isEmpty) {
                      setState(() { errorMessage = 'please_enter_current_password'.tr; });
                      return;
                    }
                    if (newPassword.isEmpty) {
                      setState(() { errorMessage = 'please_enter_new_password'.tr; });
                      return;
                    }
                    if (confirmPassword.isEmpty) {
                      setState(() { errorMessage = 'please_confirm_new_password'.tr; });
                      return;
                    }
                    if (newPassword != confirmPassword) {
                      setState(() { errorMessage = 'passwords_do_not_match'.tr; });
                      return;
                    }
                    if (newPassword.length < 6) {
                      setState(() { errorMessage = 'password_min_length'.tr; });
                      return;
                    }

                    final secureStorage = const FlutterSecureStorage();
                    final storedPassword = await secureStorage.read(key: 'password') ?? '';
                    if (storedPassword.isEmpty) {
                      setState(() { errorMessage = 'unable_verify_password'.tr; });
                      return;
                    }
                    if (currentPassword != storedPassword) {
                      setState(() { errorMessage = 'current_password_incorrect'.tr; });
                      return;
                    }
                    if (newPassword == currentPassword) {
                      setState(() { errorMessage = 'password_must_be_different'.tr; });
                      return;
                    }

                    try {
                      final result = await authController.changeUserPassword(newPassword);

                      if (currentContext.mounted) {
                        Navigator.of(currentContext).pop();
                      }

                      if (result['success']) {
                        Get.snackbar('Success',
                            'password_changed_success'.tr,
                            backgroundColor: Colors.green, colorText: Colors.white,
                            duration: const Duration(seconds: 2));

                        await Future.delayed(const Duration(milliseconds: 500));

                        await GetStorage().remove('isLoggedIn');
                        await GetStorage().remove('email');
                        await secureStorage.delete(key: 'password');
                        await GetStorage().remove('username');
                        await GetStorage().remove('empDisplayName');
                        await GetStorage().remove('webLink');
                        await GetStorage().remove('hasBiometric');
                        await GetStorage().remove('biometricEnabled');
                        await GetStorage().remove('biometricSetupComplete');

                        authController.emailOrPhone.value = '';
                        authController.password.value = '';
                        authController.newPassword.value = '';
                        authController.confirmPassword.value = '';
                        authController.verificationCode.value = '';
                        authController.errorMessage.value = '';

                        Get.offAllNamed(AppRoutes.login);
                      } else {
                        Get.snackbar('Error', result['message'] ?? 'Error changing password',
                            backgroundColor: Colors.redAccent, colorText: Colors.white);
                      }
                    } catch (e) {
                      if (currentContext.mounted) {
                        Navigator.of(currentContext).pop();
                      }
                      Get.snackbar('Error', 'Error changing password',
                          backgroundColor: Colors.redAccent, colorText: Colors.white);
                    }
                  },
                  child: Text('save'.tr),
                ),
        ],
      ),
    );
  }
}
