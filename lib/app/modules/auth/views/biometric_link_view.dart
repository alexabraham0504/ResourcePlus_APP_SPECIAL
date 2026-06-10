import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';

class BiometricLinkView extends StatefulWidget {
  const BiometricLinkView({super.key});

  @override
  State<BiometricLinkView> createState() => _BiometricLinkViewState();
}

class _BiometricLinkViewState extends State<BiometricLinkView> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // final AuthController controller = Get.find();
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
                        'Link Biometric',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: blue,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Link your biometric (Fingerprint, PIN, Face, etc.) for quick login.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
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
                                label: const Text('Link Biometric'),
                                onPressed: () async {
                                  // Use local state instead of controller
                                  setState(() {
                                    _isLoading = true;
                                  });

                                  try {
                                    // Check if biometric is available
                                    print(
                                      'Debug: Starting biometric setup process...',
                                    );

                                    final isAvailable = await controller
                                        .isBiometricAvailable();
                                    print(
                                      'Debug: Biometric available: $isAvailable',
                                    );

                                    if (!isAvailable) {
                                      // Reset loading state
                                      setState(() {
                                        _isLoading = false;
                                      });

                                      // Get more specific error info
                                      final canCheck = await controller
                                          .localAuth
                                          .canCheckBiometrics;
                                      final isSupported = await controller
                                          .localAuth
                                          .isDeviceSupported();
                                      final available = await controller
                                          .localAuth
                                          .getAvailableBiometrics();

                                      print(
                                        'Debug: canCheckBiometrics: $canCheck',
                                      );
                                      print(
                                        'Debug: isDeviceSupported: $isSupported',
                                      );
                                      print(
                                        'Debug: availableBiometrics: $available',
                                      );

                                      String errorMessage =
                                          'Biometric authentication is not available.';
                                      if (!canCheck) {
                                        errorMessage =
                                            'This device cannot check biometrics.';
                                      } else if (!isSupported) {
                                        errorMessage =
                                            'This device does not support biometric authentication.';
                                      } else if (available.isEmpty) {
                                        errorMessage =
                                            'No biometrics are enrolled on this device. Please set up fingerprint or face unlock in device settings.';
                                      }

                                      Get.snackbar(
                                        'Biometric Setup Failed',
                                        errorMessage,
                                        backgroundColor: Colors.redAccent,
                                        colorText: Colors.white,
                                        duration: const Duration(seconds: 5),
                                      );
                                      return;
                                    }

                                    print(
                                      'Debug: Proceeding with biometric authentication...',
                                    );

                                    // Test biometric authentication
                                    final authenticated = await controller
                                        .authenticateWithBiometrics();

                                    if (authenticated) {
                                      print(
                                        'Debug: Authentication successful, saving settings...',
                                      );

                                      // Mark biometric as set up first
                                      await GetStorage().write(
                                        'biometricSetupComplete',
                                        true,
                                      );
                                      await GetStorage().write(
                                        'biometricEnabled',
                                        true,
                                      );

                                      // Show success message immediately before any controller changes
                                      Get.snackbar(
                                        'Success',
                                        'Biometric authentication set up successfully!',
                                        backgroundColor: Colors.green,
                                        colorText: Colors.white,
                                      );

                                      // Reset loading state
                                      setState(() {
                                        _isLoading = false;
                                      });

                                      // Schedule navigation to avoid GetX conflicts
                                      Future.delayed(
                                        const Duration(milliseconds: 1000),
                                        () async {
                                          // Get.offAllNamed(AppRoutes.login);
                                          await GetStorage().write(
                                            'isLoggedIn',
                                            true,
                                          );
                                          await GetStorage().write(
                                            'biometricEnabled',
                                            true,
                                          );
                                          await GetStorage().write(
                                            'hasBiometric',
                                            true,
                                          );
                                          Get.offAllNamed(AppRoutes.home);
                                        },
                                      );
                                    } else {
                                      // Reset loading state
                                      setState(() {
                                        _isLoading = false;
                                      });

                                      print('Debug: Authentication failed');
                                      Get.snackbar(
                                        'Authentication Failed',
                                        'Biometric authentication was cancelled or failed. Please ensure your fingerprint/face is properly enrolled and try again.',
                                        backgroundColor: Colors.redAccent,
                                        colorText: Colors.white,
                                        duration: const Duration(seconds: 5),
                                      );
                                    }
                                  } catch (e) {
                                    // Reset loading state
                                    setState(() {
                                      _isLoading = false;
                                    });
                                    print(
                                      'Debug: Exception during biometric setup: $e',
                                    );

                                    String errorMessage =
                                        'Failed to set up biometric authentication.';
                                    if (e.toString().contains(
                                      'no_fragment_activity',
                                    )) {
                                      errorMessage =
                                          'App configuration issue. Please restart the app and try again.';
                                    } else if (e.toString().contains(
                                      'NotAvailable',
                                    )) {
                                      errorMessage =
                                          'Biometric hardware not available on this device.';
                                    } else if (e.toString().contains(
                                      'NotEnrolled',
                                    )) {
                                      errorMessage =
                                          'No biometrics enrolled. Please set up fingerprint in device settings.';
                                    } else if (e.toString().contains(
                                      'UserCancel',
                                    )) {
                                      errorMessage =
                                          'Authentication was cancelled. Please try again.';
                                    }

                                    Get.snackbar(
                                      'Setup Error',
                                      errorMessage,
                                      backgroundColor: Colors.redAccent,
                                      colorText: Colors.white,
                                      duration: const Duration(seconds: 5),
                                    );
                                  }
                                },
                              ),
                            ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () async {
                          // Skip biometric setup
                          await GetStorage().write('hasBiometric', false);
                          await GetStorage().write('isLoggedIn', true);
                          Get.offAllNamed(AppRoutes.home);
                        },
                        child: Text(
                          'Skip Biometric',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
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
