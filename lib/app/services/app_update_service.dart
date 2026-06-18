import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:in_app_update/in_app_update.dart';

/// Centralizes all Google Play in-app update logic.
/// Lives for the app's lifetime; registered once, called from splash + onResume.
class AppUpdateService extends GetxService with WidgetsBindingObserver {
  final _box = GetStorage();
  static const _kFlexSnoozeKey = 'update_flex_snoozed_until';
  
  // Tune these to your release strategy / Play Console "inAppUpdatePriority".
  static const _highPriorityThreshold = 4; // 0-5 scale set in Play Console
  static const _minStalenessDaysForFlexible = 0;
  
  bool _checking = false;
  
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // Automatically trigger first check once UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndHandleUpdate();
    });
  }
  
  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkAndHandleUpdate();
    }
  }

  /// Single entry point. Call from splash on startup, and on resume.
  Future<void> checkAndHandleUpdate() async {
    if (_checking) return; // avoid overlapping checks
    _checking = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      await _route(info);
    } catch (_) {
      // Network down, Play Store unavailable, app not installed via Play
      // (sideloaded/debug/F-Droid/emulator) -> stay silent, never block the app.
    } finally {
      _checking = false;
    }
  }

  Future<void> _route(AppUpdateInfo info) async {
    switch (info.updateAvailability) {
      case UpdateAvailability.unknown:
      case UpdateAvailability.updateNotAvailable:
        return; // Up to date -> nothing to show, nothing to remember.

      case UpdateAvailability.developerTriggeredUpdateInProgress:
        // An immediate update was already accepted but got interrupted
        // (app killed mid-update). Resume it silently.
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
        return;

      case UpdateAvailability.updateAvailable:
        final isCritical = info.updatePriority >= _highPriorityThreshold;
        
        if (isCritical && info.immediateUpdateAllowed) {
          await _runImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await _maybeOfferFlexibleUpdate(info);
        }
        return;
    }
  }

  Future<void> _runImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
      // Play restarts the app on success; if this returns, the user
      // canceled or it failed -- just let them continue using the app.
    } catch (_) {
      // Canceled / failed: don't loop forever, just try again next launch.
    }
  }

  Future<void> _maybeOfferFlexibleUpdate(AppUpdateInfo info) async {
    // Cosmetic throttle only -- NOT what determines whether an update
    // exists. Prevents re-nagging the same user every cold start.
    final snoozedUntil = _box.read<int>(_kFlexSnoozeKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < snoozedUntil) return;
    
    if ((info.clientVersionStalenessDays ?? 0) < _minStalenessDaysForFlexible) {
      return;
    }
    
    final accepted = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Update available'),
        content: const Text(
          'A new version of the app is ready. Update now for the latest features and fixes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Update'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    
    if (accepted != true) {
      // Snooze for 24h so it doesn't reappear on every relaunch this session.
      _box.write(
        _kFlexSnoozeKey,
        DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
      );
      return;
    }
    
    try {
      await InAppUpdate.startFlexibleUpdate(); // downloads in background
      _showRestartSnackbar(); // completes once downloaded
    } catch (_) {
      // User canceled the consent dialog or download failed.
    }
  }

  void _showRestartSnackbar() {
    Get.snackbar(
      'Update ready',
      'Restart to finish installing the update.',
      isDismissible: false,
      duration: const Duration(days: 1), // stays until acted on
      mainButton: TextButton(
        onPressed: () => InAppUpdate.completeFlexibleUpdate(),
        child: const Text('RESTART', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
