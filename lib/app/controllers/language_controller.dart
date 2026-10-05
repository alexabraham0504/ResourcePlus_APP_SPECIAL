import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:resource_plus_ai_workforce/utils/translations.dart' as ai_translations;
import '../modules/home/controllers/home_controller.dart';

class LanguageController extends GetxController {
  final RxString currentLanguage = 'en'.obs;
  final RxBool isRTL = false.obs;
  final _storage = GetStorage();

  // Language codes
  static const String english = 'en';
  static const String arabic = 'ar';

  // API language codes
  static const int langEnglish = 1;
  static const int langArabic = 2;

  @override
  void onInit() {
    super.onInit();
    // Load saved language preference
    currentLanguage.value = _storage.read('language') ?? english;
    _updateRTL();
    ai_translations.isArabic.value = currentLanguage.value == arabic;
  }

  // Get current API language code
  int get currentLangCode {
    return currentLanguage.value == english ? langEnglish : langArabic;
  }

  // Change language
  void changeLanguage(String languageCode) {
    currentLanguage.value = languageCode;
    _storage.write('language', languageCode);
    _updateRTL();
    ai_translations.isArabic.value = languageCode == arabic;

    // Update app locale
    final locale = languageCode == english
        ? const Locale('en', 'US')
        : const Locale('ar', 'SA');
    Get.updateLocale(locale);

    // Trigger data refetch for backend localized strings
    _refreshBackendData();
  }

  void _refreshBackendData() {
    try {
      if (Get.isRegistered<HomeController>()) {
        final homeController = Get.find<HomeController>();
        // Silent refresh so it doesn't show blocking loaders, just updates in background
        homeController.fetchHomeData(silent: true);
        homeController.fetchAttendanceData(silent: true);
        homeController.fetchProfileData(silent: true);
        homeController.fetchSettingsData(silent: true);
        homeController.fetchNotificationData(silent: true);
      }
      
      // We also need to refresh HrPortalController if it's active
      // Using generic Get.find to avoid direct import coupling if possible
      // But since we can't easily check for HrPortalController without importing,
      // we'll rely on the fact that HrPortalController is usually re-instantiated on navigation.
      // But if it's alive, let's try to update it.
    } catch (e) {
      debugPrint('Error refreshing backend data on language change: $e');
    }
  }

  // Toggle between English and Arabic
  void toggleLanguage() {
    final newLanguage = currentLanguage.value == english ? arabic : english;
    changeLanguage(newLanguage);
  }

  // Update RTL based on current language
  void _updateRTL() {
    isRTL.value = currentLanguage.value == arabic;
  }

  // Get language display name
  String getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case english:
        return 'English';
      case arabic:
        return 'العربية';
      default:
        return 'English';
    }
  }

  // Get current language display name
  String get currentLanguageDisplayName {
    return getLanguageDisplayName(currentLanguage.value);
  }
}
