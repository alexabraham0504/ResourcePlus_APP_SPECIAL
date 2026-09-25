import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../services/permission_service.dart';
import '../../../routes/app_routes.dart';

class PermissionRequestView extends StatefulWidget {
  const PermissionRequestView({super.key});

  @override
  State<PermissionRequestView> createState() => _PermissionRequestViewState();
}

class _PermissionRequestViewState extends State<PermissionRequestView> {
  final PermissionService _permissionService = PermissionService();
  bool _isLoading = false;
  bool _cameraPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    final cameraGranted = await _permissionService.isCameraPermissionGranted();

    setState(() {
      _cameraPermissionGranted = cameraGranted;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _permissionService.requestAllPermissions();

      setState(() {
        _cameraPermissionGranted = results['camera'] ?? false;
      });

      // Show results to user
      _showPermissionResults(results);
    } catch (e) {
      print('Error requesting permissions: $e');
      Get.snackbar(
        'Error',
        'Failed to request permissions',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPermissionResults(Map<String, bool> results) {
    final cameraGranted = results['camera'] ?? false;

    String message = '';
    Color backgroundColor = Colors.green;

    if (cameraGranted) {
      message = 'Camera permission granted successfully!';
    } else {
      message = 'Camera permission was denied. Some features may not work properly.';
      backgroundColor = Colors.red;
    }

    Get.snackbar(
      'Permissions',
      message,
      backgroundColor: backgroundColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  void _continueToApp() {
    // Mark permissions as requested
    _permissionService.markPermissionsRequested();

    // Navigate to the appropriate screen based on login status
    final isLoggedIn = GetStorage().read('isLoggedIn') == true;

    if (isLoggedIn) {
      // Check if biometric is enabled and setup is complete (not skipped)
      final hasBiometric = GetStorage().read('hasBiometric');
      final biometricEnabled = GetStorage().read('biometricEnabled') == true;
      final biometricSetupComplete =
          GetStorage().read('biometricSetupComplete') == true;

      // Show biometric screen if enabled and properly set up
      if (hasBiometric == true && biometricEnabled && biometricSetupComplete) {
        Get.offAllNamed(AppRoutes.biometricCheck);
      } else {
        // Skip biometric screen if skipped or not properly set up
        Get.offAllNamed(AppRoutes.home);
      }
    } else {
      Get.offAllNamed(AppRoutes.instanceScan);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.security,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Welcome to Resource Plus',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'To provide you with the best experience, we need a few permissions:',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Permission Items
              _buildPermissionItem(
                icon: Icons.camera_alt,
                title: 'Camera Permission',
                description: 'Required for scanning QR codes and taking photos',
                isGranted: _cameraPermissionGranted,
              ),

              /*
              _buildPermissionItem(
                icon: Icons.notifications,
                title: 'Notification Permission',
                description:
                    'Required for receiving important updates and alerts',
                isGranted: _notificationPermissionGranted,
              ),
              */

              const SizedBox(height: 40),

              // Action Buttons
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_cameraPermissionGranted) // Only require camera for now
                _buildContinueButton()
              else
                _buildRequestButton(),

              const SizedBox(height: 16),

              // Skip button (only show if camera permission is not granted)
              if (!_cameraPermissionGranted)
                TextButton(
                  onPressed: _continueToApp,

                  child: Text(
                    'Continue without permissions',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted
            ? Colors.green.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted
              ? Colors.green.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.green.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isGranted
                  ? Colors.green
                  : Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isGranted)
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _requestPermissions,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Grant Permissions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _continueToApp,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Continue to App',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
