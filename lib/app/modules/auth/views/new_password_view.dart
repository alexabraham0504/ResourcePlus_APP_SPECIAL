import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';

class NewPasswordView extends StatefulWidget {
  const NewPasswordView({super.key});

  @override
  State<NewPasswordView> createState() => _NewPasswordViewState();
}

class _NewPasswordViewState extends State<NewPasswordView> {
  late TextEditingController newPasswordController;
  late TextEditingController confirmPasswordController;
  final secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    newPasswordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidPassword(String password) {
    // Password must be at least 6 characters long
    return password.length >= 6;
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
                        'Set New Password',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: blue,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: newPasswordController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock, color: green),
                          helperText: 'Password must be at least 6 characters long',
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
                                  // Validate input fields
                                  if (newPasswordController.text.isEmpty) {
                                    Get.snackbar(
                                      'Error', 
                                      'Please enter a new password', 
                                      backgroundColor: Colors.redAccent, 
                                      colorText: Colors.white
                                    );
                                    return;
                                  }

                                  if (confirmPasswordController.text.isEmpty) {
                                    Get.snackbar(
                                      'Error', 
                                      'Please confirm your password', 
                                      backgroundColor: Colors.redAccent, 
                                      colorText: Colors.white
                                    );
                                    return;
                                  }

                                  if (newPasswordController.text != confirmPasswordController.text) {
                                    Get.snackbar(
                                      'Error', 
                                      'Passwords do not match', 
                                      backgroundColor: Colors.redAccent, 
                                      colorText: Colors.white
                                    );
                                    return;
                                  }

                                  if (!_isValidPassword(newPasswordController.text)) {
                                    Get.snackbar(
                                      'Error', 
                                      'Password must be at least 6 characters long', 
                                      backgroundColor: Colors.redAccent, 
                                      colorText: Colors.white
                                    );
                                    return;
                                  }

                                  // Call the API
                                  final result = await controller.changeUserPassword(newPasswordController.text);
                                  
                                  if (result['success']) {
                                    controller.newPassword.value = newPasswordController.text;
                                    await secureStorage.write(key: 'password', value: newPasswordController.text);
                                    Get.snackbar(
                                      'Success', 
                                      result['message'] ?? 'Password changed successfully', 
                                      backgroundColor: Colors.green, 
                                      colorText: Colors.white
                                    );
                                    // await GetStorage().write('isLoggedIn', true);
                                    //TODO ADD BIO
                                    Get.toNamed(AppRoutes.biometricLink);
                                    // Get.offAllNamed(AppRoutes.home);
                                  } else {
                                    Get.snackbar(
                                      'Error', 
                                      result['message'] ?? 'Password change failed', 
                                      backgroundColor: Colors.redAccent, 
                                      colorText: Colors.white
                                    );
                                  }
                                },
                                child: const Text('Set Password'),
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
