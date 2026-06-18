import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';

class BiometricCheckView extends StatefulWidget {
  const BiometricCheckView({super.key});

  @override
  State<BiometricCheckView> createState() => _BiometricCheckViewState();
}

class _BiometricCheckViewState extends State<BiometricCheckView> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometric on screen open for smoother UX
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometric();
    });
  }

  Future<void> _triggerBiometric() async {
    if (!mounted) return;
    final controller = Get.put(AuthController());
    setState(() => _isLoading = true);
    try {
      final isAvailable = await controller.isBiometricAvailable();
      if (!isAvailable || !controller.isBiometricSetupComplete()) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      final loginResult = await controller.biometricLogin();
      
      if (!mounted) return;
      if (loginResult['success'] == true) {
        setState(() => _isLoading = false);
        if (loginResult['isNeedToResetPwd'] == true) {
          Get.offAllNamed(AppRoutes.newPassword);
        } else {
          Get.offAllNamed(AppRoutes.home);
        }
      } else {
        setState(() => _isLoading = false);
        if (loginResult['message'] != 'Biometric authentication failed.') {
          await controller.logout();
          Get.snackbar(
            'Session Expired',
            loginResult['message'] ?? 'Your password has been changed. Please login again.',
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          Get.offAllNamed(AppRoutes.login);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AuthController());
    final theme = Theme.of(context);
    const blue = Color(0xFF3B6EA5);
    const green = Color(0xFF6BC04B);
    const orange = Color(0xFFF7941D);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
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
                        'Biometric Authentication',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: blue,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Icon(Icons.fingerprint, size: 80, color: green),
                      const SizedBox(height: 24),
                      const Text(
                        'Please verify your identity using biometric authentication.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.fingerprint,
                                  color: green,
                                ),
                                label: const Text('Verify Biometric'),
                                onPressed: () async {
                                  setState(() {
                                    _isLoading = true;
                                  });

                                  try {
                                    final isAvailable = await controller
                                        .isBiometricAvailable();

                                    if (!isAvailable) {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                      Get.snackbar(
                                        'Biometric Not Available',
                                        'Biometric authentication is not available on this device.',
                                        backgroundColor: Colors.redAccent,
                                        colorText: Colors.white,
                                        duration: const Duration(seconds: 5),
                                      );
                                      return;
                                    }

                                    final biometricSetup = controller
                                        .isBiometricSetupComplete();
                                    if (!biometricSetup) {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                      Get.snackbar(
                                        'Biometric Not Setup',
                                        'Biometric authentication is not set up.',
                                        backgroundColor: Colors.redAccent,
                                        colorText: Colors.white,
                                        duration: const Duration(seconds: 5),
                                      );
                                      return;
                                    }

                                    final loginResult = await controller.biometricLogin();

                                    if (loginResult['success'] == true) {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                      if (loginResult['isNeedToResetPwd'] == true) {
                                        Get.offAllNamed(AppRoutes.newPassword);
                                      } else {
                                        Get.offAllNamed(AppRoutes.home);
                                      }
                                    } else {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                      if (loginResult['message'] != 'Biometric authentication failed.') {
                                        await controller.logout();
                                        Get.snackbar(
                                          'Session Expired',
                                          loginResult['message'] ?? 'Your password has been changed. Please login again.',
                                          backgroundColor: Colors.redAccent,
                                          colorText: Colors.white,
                                          duration: const Duration(seconds: 4),
                                        );
                                        Get.offAllNamed(AppRoutes.login);
                                      } else {
                                        Get.snackbar(
                                          'Authentication Failed',
                                          'Biometric authentication failed. Use your password instead.',
                                          backgroundColor: Colors.redAccent,
                                          colorText: Colors.white,
                                          duration: const Duration(seconds: 4),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                    Get.snackbar(
                                      'Verification Error',
                                      'Biometric verification failed. Please use your password.',
                                      backgroundColor: Colors.redAccent,
                                      colorText: Colors.white,
                                      duration: const Duration(seconds: 5),
                                    );
                                  }
                                },
                              ),
                            ),
                      const SizedBox(height: 16),
                      // Critical fallback for Android 11-14 where biometric can fail
                      TextButton(
                        onPressed: () async {
                          // Clear biometric flags so user re-enters via password login
                          await GetStorage().remove('hasBiometric');
                          await GetStorage().remove('biometricEnabled');
                          await GetStorage().remove('biometricSetupComplete');
                          await GetStorage().write('isLoggedIn', false);
                          Get.offAllNamed(AppRoutes.login);
                        },
                        child: Text(
                          'Use Password Instead',
                          style: TextStyle(
                            color: blue,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
