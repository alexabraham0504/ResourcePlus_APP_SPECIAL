import 'package:get/get.dart';
import '../modules/auth/views/instance_scan_view.dart';
import '../modules/auth/views/email_verification_view.dart';
import '../modules/auth/views/code_verification_view.dart';
import '../modules/auth/views/password_view.dart';
import '../modules/auth/views/new_password_view.dart';
import '../modules/auth/views/biometric_link_view.dart';
import '../modules/auth/views/biometric_check_view.dart';
import '../modules/auth/views/permission_request_view.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/forgot_password_view.dart';
import '../modules/auth/views/dynamic_url_view.dart';
import '../modules/home/views/home_view.dart';
import '../modules/home/views/webview_page.dart';
import '../modules/home/views/hr_portal_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/controllers/hr_portal_controller.dart';
import '../modules/auth/views/privacy_consent_view.dart';
import '../modules/auth/views/privacy_terms_detail_view.dart';
import '../modules/home/views/widgets/attendance_history_view.dart';
import '../modules/home/views/update_required_view.dart';
import 'update_guard_middleware.dart';
import 'app_routes.dart';

class AppPages {
  static const initial = AppRoutes.instanceScan;
  static const bioCheck = AppRoutes.biometricCheck;
  static const initialLogin = AppRoutes.instanceScan;
  static const initialHome = AppRoutes.home;
  static const emailPassLogin = AppRoutes.login;
  
  static final routes = [
    GetPage(name: AppRoutes.instanceScan, page: () => const InstanceScanView()),
    GetPage(
      name: AppRoutes.emailVerification,
      page: () => const EmailVerificationView(),
    ),
    GetPage(
      name: AppRoutes.codeVerification,
      page: () => const CodeVerificationView(),
    ),
    GetPage(name: AppRoutes.password, page: () => const PasswordView()),
    GetPage(name: AppRoutes.newPassword, page: () => const NewPasswordView()),
    GetPage(
      name: AppRoutes.biometricLink,
      page: () => const BiometricLinkView(),
    ),
    GetPage(
      name: AppRoutes.biometricCheck,
      page: () => const BiometricCheckView(),
    ),
    GetPage(
      name: AppRoutes.permissionRequest,
      page: () => const PermissionRequestView(),
    ),
    GetPage(name: AppRoutes.login, page: () => const LoginView()),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordView(),
    ),
    GetPage(name: AppRoutes.dynamicUrl, page: () => const DynamicUrlView()),
    GetPage(
      name: AppRoutes.webview,
      page: () => WebViewPage(
        url: Get.parameters['url'] ?? '',
        title: Get.parameters['title'] ?? 'Web Page',
      ),
      middlewares: [UpdateGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.home, 
      page: () => const HomeView(),
      binding: HomeBinding(),
      middlewares: [UpdateGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.hrPortal,
      page: () => const HrPortalView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => HrPortalController())),
      middlewares: [UpdateGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.privacyConsent,
      page: () => const PrivacyConsentView(),
    ),
    GetPage(
      name: AppRoutes.privacyTermsDetail,
      page: () => const PrivacyTermsDetailView(),
    ),
    GetPage(
      name: AppRoutes.attendanceHistory,
      page: () => const AttendanceHistoryView(),
      middlewares: [UpdateGuardMiddleware()],
    ),
    GetPage(
      name: AppRoutes.updateRequired,
      page: () => const UpdateRequiredView(),
    ),
  ];
} 
