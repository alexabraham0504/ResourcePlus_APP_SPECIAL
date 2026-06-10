import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  late TextEditingController emailController;
  late TextEditingController tempPasswordController;
  late TextEditingController newPasswordController;
  late TextEditingController confirmPasswordController;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    tempPasswordController = TextEditingController();
    newPasswordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    tempPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController controller = Get.find();
    final theme = Theme.of(context);
    const blue = Color(0xFF3B6EA5);
    const green = Color(0xFF6BC04B);
    const orange = Color(0xFFF7941D);

    return Scaffold(
      backgroundColor: Colors.white,
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
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Forgot Password',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: blue,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: emailController,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Email or Phone',
                          prefixIcon: const Icon(Icons.alternate_email, color: green),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Obx(() => controller.isLoading.value
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () async {
                                  controller.isLoading.value = true;
                                  final valid = await controller.validateEmailOrPhone(emailController.text);
                                  controller.isLoading.value = false;
                                  if (valid) {
                                    await controller.sendVerificationCode(emailController.text);
                                    Get.snackbar('Success', 'Temporary password sent', backgroundColor: Colors.green, colorText: Colors.white);
                                  } else {
                                    Get.snackbar('Error', 'Invalid email or phone', backgroundColor: Colors.redAccent, colorText: Colors.white);
                                  }
                                },
                                child: const Text('Send Temp Password'),
                              ),
                            )),
                      const SizedBox(height: 24),
                      TextField(
                        controller: tempPasswordController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Temporary Password',
                          prefixIcon: const Icon(Icons.lock, color: green),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: newPasswordController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock, color: green),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: green),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Obx(() => controller.isLoading.value
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () async {
                                  if (newPasswordController.text != confirmPasswordController.text) {
                                    Get.snackbar('Error', 'Passwords do not match', backgroundColor: Colors.redAccent, colorText: Colors.white);
                                    return;
                                  }
                                  controller.isLoading.value = true;
                                  final valid = await controller.changePassword(newPasswordController.text);
                                  controller.isLoading.value = false;
                                  if (valid) {
                                    Get.snackbar('Success', 'Password changed successfully', backgroundColor: Colors.green, colorText: Colors.white);
                                    Get.offAllNamed(AppRoutes.login);
                                  } else {
                                    Get.snackbar('Error', 'Password does not meet requirements', backgroundColor: Colors.redAccent, colorText: Colors.white);
                                  }
                                },
                                child: const Text('Change Password'),
                              ),
                            )),
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