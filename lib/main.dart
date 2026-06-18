import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/controllers/theme_controller.dart';
import 'app/controllers/language_controller.dart';
import 'app/translations/app_translations.dart';
import 'app/services/api_service.dart';
import 'app/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'app/widgets/error_page_widget.dart';
import 'app/services/cache_service.dart';
import 'app/services/app_update_service.dart';
import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Set global error widget to replace the default red error screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Builder(
      builder: (context) {
        // Try to get media query size, fallback if not available
        Size size;
        try {
          size = MediaQuery.of(context).size;
        } catch (_) {
          size = const Size(400, 800);
        }

        return MediaQuery(
          data: MediaQueryData(size: size),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: FuturisticErrorPage(
                onRetry: () {
                  if (Get.context != null) {
                    Get.offAllNamed(AppRoutes.home);
                  }
                },
                errorType: ErrorType.unknown,
                customMessage: kDebugMode 
                    ? details.summary.toString() 
                    : 'An unexpected error occurred.',
              ),
            ),
          ),
        );
      }
    );
  };

  await GetStorage.init();

  // 1. Check for app update and clear selective cache if needed
  await CacheService.checkAndClearCacheOnUpdate();

  // Initialize date formatting for all locales
  await initializeDateFormatting('en_US', null);
  await initializeDateFormatting('ar_SA', null);

  // Initialize API service with SSL certificate handling
  final apiService = ApiService();
  apiService.initialize();

  // Notification service disabled for this release
  // final notificationService = NotificationService();
  // await notificationService.initialize();

  // Notification permission request disabled
  // if (await Permission.notification.isDenied) {
  //   await Permission.notification.request();
  // }

  // Initialize mandatory update service lifecycle
  Get.put(AppUpdateService(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  String _getInitialRoute() {
    final storage = GetStorage();

    // Check privacy consent first
    final bool privacyAccepted = storage.read('privacyAccepted') == true;
    if (!privacyAccepted) {
      return AppRoutes.privacyConsent;
    }

    // Read all values up front to avoid repeated reads on older Android
    final bool permissionsRequested = storage.read('permissionsRequested') == true;
    final bool isLoggedIn = storage.read('isLoggedIn') == true;
    final String instanceName = (storage.read('instanceName') ?? '').toString();
    // Security flag: tracks whether the user completed the mandatory OTP verification
    final bool otpVerified = storage.read('otpVerified') == true;

    // Permissions request screen bypassed for testing/release with reduced permissions
    if (!permissionsRequested) {
      storage.write('permissionsRequested', true);
    }

    if (isLoggedIn) {
      // Check if biometric is enabled and setup is complete (not skipped)
      final hasBiometric = storage.read('hasBiometric');
      final biometricEnabled = storage.read('biometricEnabled') == true;
      final biometricSetupComplete =
          storage.read('biometricSetupComplete') == true;

      // Show biometric screen if:
      // 1. hasBiometric is true (not skipped), AND
      // 2. biometric is enabled AND setup is complete
      if (hasBiometric == true && biometricEnabled && biometricSetupComplete) {
        return AppRoutes.biometricCheck;
      } else {
        // Skip biometric screen if skipped or not properly set up
        return AppRoutes.home;
      }
    } else {
      // SECURITY FIX: Only allow direct login screen if the user has
      // previously completed the full OTP verification flow.
      // If they closed the app mid-verification (before OTP was validated),
      // force them back to the instance scan to restart the full flow.
      if (instanceName.isNotEmpty && otpVerified) {
        return AppRoutes.login;
      }
      // Clear any partial instance data from interrupted first-time flows
      // to prevent stale state from confusing future login attempts
      if (!otpVerified && instanceName.isNotEmpty) {
        storage.remove('instanceName');
        storage.remove('email');
      }
      return AppPages.initialLogin;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize controllers
    final themeController = Get.put(ThemeController());
    final languageController = Get.put(LanguageController());

    // Logo theme colors for auth screens
    const blue = Color(0xFF3B6EA5);
    const green = Color(0xFF6BC04B);
    const orange = Color(0xFFF7941D);

    return GetMaterialApp(
      translations: AppTranslations(),
      locale: languageController.currentLanguage.value == 'en'
          ? const Locale('en', 'US')
          : const Locale('ar', 'SA'),
      fallbackLocale: const Locale('en', 'US'),
      textDirection: languageController.isRTL.value
          ? TextDirection.rtl
          : TextDirection.ltr,
      title: 'Resource Plus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: blue,
          secondary: green,
          surface: Colors.white,
          background: Colors.white,
          error: orange,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: orange, width: 2),
          ),
          fillColor: blue.withOpacity(0.05),
          filled: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            elevation: 4,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: blue),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: blue),
          titleTextStyle: TextStyle(
            color: blue,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A), // Android 17 deeper dark
        colorScheme: const ColorScheme.dark(
          primary: blue,
          secondary: green,
          surface: Color(0xFF141414), // Softer contrast surface
          background: Color(0xFF0A0A0A),
          error: orange,
          onBackground: Colors.white,
          onSurface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white),
          displayMedium: TextStyle(color: Colors.white),
          displaySmall: TextStyle(color: Colors.white),
          headlineLarge: TextStyle(color: Colors.white),
          headlineMedium: TextStyle(color: Colors.white),
          headlineSmall: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
          titleSmall: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white70),
          labelLarge: TextStyle(color: Colors.white),
          labelMedium: TextStyle(color: Colors.white),
          labelSmall: TextStyle(color: Colors.white70),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), // Android 17 pill shape
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: green, width: 2), // Subtle green highlight
          ),
          fillColor: const Color(0xFF141414),
          filled: true,
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white54),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: green, // Primary green action
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24), // Pill shape
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            elevation: 8, // Subtle shadow for depth
            shadowColor: green.withOpacity(0.5), // Ambient green glow
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: green),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF141414),
          elevation: 4, // Elevation triggers shadow
          shadowColor: green.withOpacity(0.15), // Android 17 subtle ambient green glow
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF141414),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white70,
        ),
      ),
      themeMode:
          themeController.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
      initialRoute: _getInitialRoute(),

      // : GetStorage().read('instanceName') == null ||
      //       GetStorage().read('instanceName').toString().isEmpty
      // ? AppPages.initialLogin
      // : AppPages.emailPassLogin,
      getPages: AppPages.routes,
      unknownRoute: GetPage(
        name: '/notfound',
        page: () => Scaffold(
          body: FuturisticErrorPage(
            onRetry: () {
              Get.offAllNamed(AppRoutes.home);
            },
            errorType: ErrorType.unknown,
            customMessage: 'Page not found.',
          ),
        ),
      ),
    );
  }
}
