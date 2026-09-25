import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/app_update_service.dart';

/// UpdateRequiredView — Mandatory Update Blocking Screen
///
/// This screen is shown when a mandatory update is available.
///
/// Security features:
///   - PopScope canPop: false → Android back button is disabled
///   - SystemNavigator.pop() is NOT called → user cannot leave
///   - No "Later" button, no "Skip" button, no dismiss
///   - Only action: "Update Now" (tries Play Core, then Play Store URL)
///   - On resume from Play Store, AppUpdateService rechecks automatically
///   - If update was installed, user proceeds normally
///   - If update was NOT installed, user stays blocked here
class UpdateRequiredView extends StatelessWidget {
  const UpdateRequiredView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false, // CRITICAL: Disable Android back button
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),

                // Update icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    size: 64,
                    color: Color(0xFF1E3A8A),
                  ),
                ),

                const SizedBox(height: 40),

                // Title
                Text(
                  'update_required'.tr.isEmpty ? 'Update Required' : 'update_required'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                Text(
                  'update_required_message'.tr.isEmpty
                      ? 'A new version of ResourcePlus ESS is available.\n\nPlease update to the latest version to continue using the application securely.'
                      : 'update_required_message'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 2),

                // Primary action: Update Now
                // First tries Play Core immediate update, then opens Play Store URL
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final updateService = Get.find<AppUpdateService>();

                      // First, try the in-app update flow (Play Core).
                      // If it succeeds, Play restarts the app.
                      // If it fails/cancels, we open the Play Store as fallback.
                      await updateService.checkAndHandleUpdate();

                      // If we're still on this screen, in-app update didn't work.
                      // Open Play Store directly as fallback.
                      await updateService.openPlayStore();
                    },
                    icon: const Icon(Icons.download_rounded, size: 24),
                    label: Text(
                      'update_now'.tr.isEmpty ? 'Update Now' : 'update_now'.tr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Secondary fallback: Open Play Store directly
                TextButton(
                  onPressed: () {
                    Get.find<AppUpdateService>().openPlayStore();
                  },
                  child: Text(
                    Platform.isIOS 
                        ? ('open_app_store'.tr.isEmpty ? 'Open App Store' : 'open_app_store'.tr)
                        : ('open_play_store'.tr.isEmpty ? 'Open Play Store' : 'open_play_store'.tr),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
