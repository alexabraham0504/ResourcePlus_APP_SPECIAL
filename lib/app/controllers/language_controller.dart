import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

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

    // Update app locale
    final locale = languageCode == english
        ? const Locale('en', 'US')
        : const Locale('ar', 'SA');

    Get.updateLocale(locale);
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
