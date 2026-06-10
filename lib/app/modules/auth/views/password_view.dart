import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/custom_popup.dart';

class PasswordView extends StatefulWidget {
  const PasswordView({super.key});

  @override
  State<PasswordView> createState() => _PasswordViewState();
}

class _PasswordViewState extends State<PasswordView> {
  late TextEditingController passwordController;

  @override
  void initState() {
    super.initState();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController controller = Get.find();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
                color: theme.colorScheme.surface,
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
                        'Enter Password',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(
                            Icons.lock,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => controller.errorMessage.value.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  controller.errorMessage.value,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => controller.isLoading.value
                            ? CircularProgressIndicator(
                                color: theme.colorScheme.primary,
                              )
                            : SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor:
                                        theme.colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (passwordController.text.isEmpty) {
                                      controller.errorMessage.value = 'Please enter your password';
                                      CustomPopup.show(
                                        context: context,
                                        title: 'Validation Error',
                                        message: 'Please enter your password',
                                        type: CustomPopupType.warning,
                                      );
                                      return;
                                    }
                                    controller.errorMessage.value = '';

                                    print('DEBUG: [PasswordView] Continue button clicked.');
                                    final result = await controller
                                        .validateUserLogin(
                                          passwordController.text,
                                        );
                                    print('DEBUG: [PasswordView] result=$result');

                                    if (result['success']) {
                                      controller.password.value =
                                          passwordController.text;

                                      // Check if password reset is needed
                                      if (result['isNeedToResetPwd'] == true) {
                                        Get.toNamed(AppRoutes.newPassword);
                                      } else {
                                        // Save isLoggedIn BEFORE navigating to biometric page.
                                        // This ensures the session persists even if biometric
                                        // setup is interrupted (critical fix for Android 11-14).
                                        await GetStorage().write('isLoggedIn', true);
                                        Get.toNamed(AppRoutes.biometricLink);
                                      }
                                    } else {
                                      print('DEBUG: [PasswordView] Login failed. Error: ${result['message']}');
                                      controller.errorMessage.value = result['message'] ?? 'Invalid password';
                                      CustomPopup.show(
                                        context: context,
                                        title: 'Login Failed',
                                        message: result['message'] ?? 'Your login attempt was not successful. Please try again.',
                                        type: CustomPopupType.error,
                                      );
                                    }
                                  },
                                  child: const Text('Continue'),
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
