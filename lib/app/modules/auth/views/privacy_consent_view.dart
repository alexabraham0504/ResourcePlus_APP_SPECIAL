import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../routes/app_routes.dart';

class PrivacyConsentView extends StatefulWidget {
  const PrivacyConsentView({super.key});

  @override
  State<PrivacyConsentView> createState() => _PrivacyConsentViewState();
}

class _PrivacyConsentViewState extends State<PrivacyConsentView> {
  final _storage = GetStorage();
  bool _hasAccepted = false;

  void _onAgree() {
    setState(() {
      _hasAccepted = true;
    });
    
    // Save state
    _storage.write('privacyAccepted', true);
    
    // Go to permission request or home depending on state
    final bool permissionsRequested = _storage.read('permissionsRequested') == true;
    if (!permissionsRequested) {
      Get.offAllNamed(AppRoutes.permissionRequest);
    } else {
      // Direct routing if permissions are already granted
      final bool isLoggedIn = _storage.read('isLoggedIn') == true;
      if (isLoggedIn) {
        final hasBiometric = _storage.read('hasBiometric');
        final biometricEnabled = _storage.read('biometricEnabled') == true;
        final biometricSetupComplete = _storage.read('biometricSetupComplete') == true;

        if (hasBiometric == true && biometricEnabled && biometricSetupComplete) {
          Get.offAllNamed(AppRoutes.biometricCheck);
        } else {
          Get.offAllNamed(AppRoutes.home);
        }
      } else {
        Get.offAllNamed(AppRoutes.instanceScan);
      }
    }
  }

  void _onCancel() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 28),
              const SizedBox(width: 10),
              Text(
                'consent_required'.tr,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'consent_required_desc'.tr,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'go_back'.tr,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Exit app
                if (Platform.isAndroid) {
                  SystemNavigator.pop();
                } else if (Platform.isIOS) {
                  exit(0);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('exit_app'.tr),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    final errorColor = Theme.of(context).colorScheme.error;
    final onBackgroundColor = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top Logo / Security Shield Icon
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 48,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Title
                    Text(
                      'privacy_terms_consent'.tr,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: onBackgroundColor,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    // Header Subtitle
                    Text(
                      'privacy_consent_subtitle'.tr,
                      style: TextStyle(
                        fontSize: 15,
                        color: onBackgroundColor.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Feature Cards (Selfie, Location, Device ID)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey.withOpacity(0.08)
                                : Colors.black.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.grey.withOpacity(0.15)
                              : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'why_collect_data'.tr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDataPointRow(
                            context: context,
                            icon: Icons.face_retouching_natural,
                            title: 'selfie_image'.tr,
                            description: 'selfie_image_desc'.tr,
                          ),
                          const Divider(height: 24),
                          _buildDataPointRow(
                            context: context,
                            icon: Icons.location_on_outlined,
                            title: 'location_coordinates'.tr,
                            description: 'location_desc'.tr,
                          ),
                          const Divider(height: 24),
                          _buildDataPointRow(
                            context: context,
                            icon: Icons.phonelink_setup_outlined,
                            title: 'device_id'.tr,
                            description: 'device_id_desc'.tr,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Main Consent Text with Hyperlinks
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.1),
                        ),
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: onBackgroundColor.withOpacity(0.8),
                            fontFamily: 'Roboto',
                          ),
                          children: [
                            TextSpan(text: 'consent_statement_1'.tr),
                            TextSpan(
                              text: 'privacy_policy'.tr,
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Get.toNamed(AppRoutes.privacyTermsDetail, arguments: 'privacy');
                                },
                            ),
                            TextSpan(text: 'consent_statement_2'.tr),
                            TextSpan(
                              text: 'terms_conditions'.tr,
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Get.toNamed(AppRoutes.privacyTermsDetail, arguments: 'terms');
                                },
                            ),
                            TextSpan(text: 'consent_statement_3'.tr),
                            TextSpan(
                              text: 'do_you_agree'.tr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: onBackgroundColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            
            // Bottom Consent Buttons
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // I Agree Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _onAgree,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: errorColor, // matching the app theme orange button color
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'i_agree'.tr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Cancel / Do Not Agree Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _onCancel,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: onBackgroundColor.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'cancel_not_agree'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          color: onBackgroundColor.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPointRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
