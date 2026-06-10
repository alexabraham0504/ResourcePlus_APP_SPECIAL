import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';

class EmailVerificationView extends StatefulWidget {
  const EmailVerificationView({super.key});

  @override
  State<EmailVerificationView> createState() => _EmailVerificationViewState();
}

class _EmailVerificationViewState extends State<EmailVerificationView> {
  late TextEditingController emailController;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
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
                        'Enter Email Address',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We\'ll send a verification code to your email',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'Enter your email address',
                          prefixIcon: Icon(
                            Icons.alternate_email,
                            color: theme.colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
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
                                    if (emailController.text.trim().isEmpty) {
                                      controller.errorMessage.value = 'Please enter an email address';
                                      Get.snackbar(
                                        'Error',
                                        'Please enter an email address',
                                        backgroundColor:
                                            theme.colorScheme.error,
                                        colorText: theme.colorScheme.onError,
                                      );
                                      return;
                                    }
                                    controller.errorMessage.value = '';

                                    final success =
                                        await controller.sendVerificationCode(
                                      emailController.text.trim(),
                                    );
                                    if (success) {
                                      controller.emailOrPhone.value =
                                          emailController.text.trim();
                                      Get.toNamed(AppRoutes.codeVerification);
                                    } else {
                                      Get.snackbar(
                                        'Error',
                                        controller.errorMessage.value.isNotEmpty
                                            ? controller.errorMessage.value
                                            : 'Failed to send verification code',
                                        backgroundColor:
                                            theme.colorScheme.error,
                                        colorText: theme.colorScheme.onError,
                                      );
                                    }
                                  },
                                  child: const Text('Send Code'),
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
