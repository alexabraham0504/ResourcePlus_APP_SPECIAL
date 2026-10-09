import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/custom_popup.dart';
import '../../../services/app_update_service.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _biometricAvailable = false;
  bool _isCheckingBiometric = true;
  bool _isLockedEmail = false;
  late TextEditingController usernameController;
  late TextEditingController passwordController;

  @override
  void initState() {
    super.initState();
    Get.put(AuthController());
    
    final savedEmail = GetStorage().read('email');
    final savedUsername = GetStorage().read('username');
    String initialUsername = '';
    
    if (savedEmail != null && savedEmail.toString().isNotEmpty) {
      initialUsername = savedEmail.toString();
      _isLockedEmail = true;
    } else if (savedUsername != null && savedUsername.toString().isNotEmpty) {
      initialUsername = savedUsername.toString();
      _isLockedEmail = true;
    }

    usernameController = TextEditingController(text: initialUsername);
    passwordController = TextEditingController();
    _checkBiometricAvailability();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Get.put(AuthController());
    // Refresh biometric availability when returning to this screen
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final controller = Get.find<AuthController>();
    try {
      final isAvailable = await controller.isBiometricAvailable();
      final biometricSetup = controller.isBiometricSetupComplete();

      if (mounted) {
        setState(() {
          _biometricAvailable = isAvailable && biometricSetup;
          _isCheckingBiometric = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
          _isCheckingBiometric = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController controller = Get.put(AuthController());
    final theme = Theme.of(context);
    const blue = Color(0xFF3B6EA5);
    const green = Color(0xFF6BC04B);
    const orange = Color(0xFFF7941D);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Image.asset(
                  'assets/app_logo.png',
                  height: 80,
                  width: 280,
                ),
              ),
              Card(
                elevation: 8,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'login_title'.tr,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: usernameController,
                        readOnly: _isLockedEmail,
                        enableInteractiveSelection: !_isLockedEmail,
                        canRequestFocus: !_isLockedEmail,
                        style: TextStyle(
                          fontSize: 16, 
                          color: _isLockedEmail ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey[500] : Colors.grey[600]) : null
                        ),
                        decoration: InputDecoration(
                          labelText: 'username_or_email'.tr,
                          prefixIcon: Icon(
                            Icons.person,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'password'.tr,
                          prefixIcon: Icon(
                            Icons.lock,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              // Get.toNamed(AppRoutes.forgotPassword);
                              Get.toNamed(AppRoutes.newPassword);
                            },
                            child: Text(
                              'forgot_password'.tr,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          // Show biometric button only if available and set up
                          if (!_isCheckingBiometric && _biometricAvailable)
                            IconButton(
                              icon: Icon(
                                Icons.fingerprint,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () async {
                                final result = await controller
                                    .biometricLogin();

                                if (result['success']) {
                                  if (result['isNeedToResetPwd']) {
                                    // Route to new password screen
                                    Get.offAllNamed(AppRoutes.newPassword);
                                  } else {
                                    // Route to home screen
                                    Get.offAllNamed(AppRoutes.home);
                                  }
                                } else {
                                  CustomPopup.show(
                                    context: context,
                                    title: 'Biometric Failed',
                                    message: result['message'] ?? 'Biometric login failed',
                                    type: CustomPopupType.error,
                                  );
                                }
                              },
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => controller.isLoading.value
                            ? CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (usernameController.text.isEmpty ||
                                        passwordController.text.isEmpty) {
                                      CustomPopup.show(
                                        context: context,
                                        title: 'Validation Error',
                                        message: 'Please enter both username/email and password',
                                        type: CustomPopupType.warning,
                                      );
                                      return;
                                    }

                                    print('DEBUG: [LoginView] Login button clicked. username=${usernameController.text}');
                                    final result = await controller
                                        .loginWithStoredInstance(
                                          usernameController.text,
                                          passwordController.text,
                                        );
                                    print('DEBUG: [LoginView] Login result=$result');

                                    if (result['success']) {
                                      if (result['isNeedToResetPwd'] == true) {
                                        // Route to new password screen
                                        Get.offAllNamed(AppRoutes.newPassword);
                                      } else {
                                        // Save isLoggedIn BEFORE navigating to biometric page.
                                        // This ensures the session persists even if biometric
                                        // setup is interrupted (critical fix for Android 11-14).
                                        await GetStorage().write('isLoggedIn', true);

                                        // MANDATORY UPDATE CHECK after login success.
                                        // If an update is available, user is blocked on
                                        // UpdateRequiredView and never reaches biometric/dashboard.
                                        try {
                                          final updateService = Get.find<AppUpdateService>();
                                          await updateService.checkAndHandleUpdate();
                                        } catch (_) {}

                                        // After login, route to biometric link page
                                        // User can set up biometric or skip it.
                                        // (Only reached if no update is required)
                                        if (Get.currentRoute != AppRoutes.updateRequired) {
                                          Get.offAllNamed(
                                            AppRoutes.biometricLink,
                                          );
                                        }
                                      }
                                    } else {
                                      print('DEBUG: [LoginView] Login failed. Error: ${result['message']}');
                                      CustomPopup.show(
                                        context: context,
                                        title: 'Login Failed',
                                        message: result['message'] ?? 'Your login attempt was not successful. Please try again.',
                                        type: CustomPopupType.error,
                                      );
                                    }
                                  },
                                  child: Text('login_title'.tr),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
