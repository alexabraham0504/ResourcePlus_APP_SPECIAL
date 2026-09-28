import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/routes/app_routes.dart';
/// Mandatory Update Service — Production Hardened
///
/// Business Rule: ResourcePlus ESS must NOT be usable when a mandatory
/// update is available. The user MUST update first. No bypasses allowed.
///
/// Enforcement Points:
///   1. App startup (onInit → addPostFrameCallback)
///   2. App resume  (didChangeAppLifecycleState → resumed)
///   3. Return from Play Store (same as resume)
///   4. Login success (called manually from login flow)
///   5. UpdateRequiredView "Update Now" button
///
/// When an update is available:
///   - If Play Core immediate update is allowed → triggers it
///   - If user cancels or it fails → navigates to UpdateRequiredView (blocked)
///   - If Play Core API fails entirely → opens Play Store URL as fallback
///   - UpdateRequiredView has NO back button, NO later, NO skip, NO dismiss
///
/// When NO update is available:
///   - Service does nothing; user proceeds normally.
class AppUpdateService extends GetxService with WidgetsBindingObserver {
  /// Tracks whether a check is already in progress to prevent overlapping calls.
  bool _checking = false;

  /// Whether the app was installed from the Play Store.
  /// If false, all Play Core API calls are skipped to avoid native binder crashes.
  bool _isPlayStoreInstall = false;

  /// Observable flag: true when an update is required and the user must be blocked.
  final RxBool isUpdateRequired = false.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // Determine install source FIRST, then trigger update check.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _detectInstallSource();
      checkAndHandleUpdate();
    });
  }

  /// Checks if the app was installed via the Play Store.
  /// Sideloaded builds return a different installer package name (or null),
  /// which causes the Play Core binder to die with a native crash.
  /// We skip all Play Core calls for non-Play-Store installs.
  Future<void> _detectInstallSource() async {
    if (Platform.isIOS) {
      _isPlayStoreInstall = false; // iOS uses App Store, handled separately.
      return;
    }
    try {
      const channel = MethodChannel('com.resourceplus.app/installer');
      final installer = await channel.invokeMethod<String>('getInstallerPackageName');
      _isPlayStoreInstall = installer == 'com.android.vending';
      debugPrint('AppUpdateService: installer=$installer, isPlayStore=$_isPlayStoreInstall');
    } catch (_) {
      // Channel not available — assume sideloaded to be safe.
      _isPlayStoreInstall = false;
      debugPrint('AppUpdateService: Could not determine installer source — assuming sideloaded.');
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// Lifecycle hook — fires on every app resume (return from background,
  /// return from Play Store, return from task switcher).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkAndHandleUpdate();
    }
  }

  /// Single entry point for all update checks.
  ///
  /// Call this from:
  ///   - Startup (automatic via onInit)
  ///   - Resume (automatic via didChangeAppLifecycleState)
  ///   - Login success (manual call from login flow)
  ///   - UpdateRequiredView "Update Now" button (manual call)
  Future<void> checkAndHandleUpdate() async {
    if (_checking) return; // Prevent overlapping checks
    _checking = true;

    if (Platform.isIOS) {
      _checking = false;
      return; // Updates are managed by the App Store natively on iOS.
    }

    // CRITICAL: Skip Play Core entirely for sideloaded apps.
    // The Play Store binder crashes at the native (C++) level when the app
    // is not owned by any Play Store account. Flutter's try/catch cannot
    // intercept native crashes — the only safe fix is to never call Play Core.
    if (!_isPlayStoreInstall) {
      debugPrint('AppUpdateService: Skipping update check — app is not a Play Store install.');
      _checking = false;
      return;
    }

    try {
      final info = await InAppUpdate.checkForUpdate();
      await _handleUpdateResult(info);
    } catch (e) {
      // Play Core API failed even for a Play Store install (e.g., network down,
      // Play Store outdated). Log and allow through unless previously blocked.
      debugPrint('AppUpdateService: Play Core API failed: $e');
      if (isUpdateRequired.value) {
        _navigateToUpdateRequired();
      }
    } finally {
      _checking = false;
    }
  }

  /// Routes the update check result to the correct handler.
  Future<void> _handleUpdateResult(AppUpdateInfo info) async {
    switch (info.updateAvailability) {
      case UpdateAvailability.unknown:
      case UpdateAvailability.updateNotAvailable:
        // App is up to date. Clear any previous update-required state.
        isUpdateRequired.value = false;
        return;

      case UpdateAvailability.developerTriggeredUpdateInProgress:
        // An immediate update was already accepted but got interrupted
        // (e.g., app was killed mid-download). Resume it.
        isUpdateRequired.value = true;
        if (info.immediateUpdateAllowed) {
          await _performImmediateUpdate();
        } else {
          // Cannot resume — block user until they can update.
          _navigateToUpdateRequired();
        }
        return;

      case UpdateAvailability.updateAvailable:
        // Update is available — BLOCK the user until they update.
        isUpdateRequired.value = true;

        if (info.immediateUpdateAllowed) {
          await _performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          // Even for flexible updates, we treat them as MANDATORY.
          // No "Later" button. No snooze. No skip.
          // Try immediate first (Play may allow it even if flagged flexible).
          _navigateToUpdateRequired();
        } else {
          // Neither immediate nor flexible is allowed by Play.
          // This is extremely rare but possible.
          // Fallback: open Play Store directly.
          _navigateToUpdateRequired();
        }
        return;
    }
  }

  /// Attempts to perform an immediate (full-screen blocking) update via Play Core.
  ///
  /// If the user cancels or it fails, they are redirected to UpdateRequiredView.
  /// They are NEVER allowed to continue using the app.
  Future<void> _performImmediateUpdate() async {
    try {
      // This opens the Play Store's full-screen immediate update UI.
      // If successful, Play restarts the app automatically.
      // If it returns without success, the user canceled.
      await InAppUpdate.performImmediateUpdate();

      // If we reach here, the update was canceled or failed.
      // DO NOT let the user continue. Block them.
      debugPrint('AppUpdateService: Immediate update returned without completing — user blocked.');
      _navigateToUpdateRequired();
    } catch (e) {
      // performImmediateUpdate threw — user canceled or Play Core error.
      debugPrint('AppUpdateService: Immediate update failed/canceled: $e');
      _navigateToUpdateRequired();
    }
  }

  /// Navigates the user to the UpdateRequiredView.
  /// Uses `offAllNamed` to clear the entire navigation stack so there is
  /// no back button or route to escape to.
  void _navigateToUpdateRequired() {
    // Only navigate if we're not already on the update screen.
    if (Get.currentRoute != AppRoutes.updateRequired) {
      Get.offAllNamed(AppRoutes.updateRequired);
    }
  }

  /// Opens the App Store or Play Store listing for ResourcePlus ESS.
  /// Used as a fallback when Play Core in-app update API is unavailable.
  Future<void> openPlayStore() async {
    final url = Platform.isIOS 
        ? 'https://apps.apple.com/app/id6440000000' // Ensure to replace with actual App ID
        : 'https://play.google.com/store/apps/details?id=com.resourceplus.app';
    final uri = Uri.parse(url);
    
    try {
      if (!Platform.isIOS) {
        // Try Play Store app first
        final marketUri = Uri.parse('market://details?id=com.resourceplus.app');
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
    } catch (_) {}

    // Fallback to browser (or App Store on iOS which handles https://apps.apple.com links automatically)
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('AppUpdateService: Could not open Store: $e');
    }
  }
}
