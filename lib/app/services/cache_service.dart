import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';

class CacheService {
  static Future<void> checkAndClearCacheOnUpdate() async {
    final storage = GetStorage();
    const secureStorage = FlutterSecureStorage();

    // --- First-Install & Reinstall Detection Logic ---
    bool isReinstallWithRestoredBackup = false;
    
    try {
      // Attempt to read a key from secure storage.
      // If Auto Backup restored the encrypted SharedPreferences but the Android Keystore
      // was wiped during uninstall, this read will throw a PlatformException.
      // This is the definitive way to detect a restored backup after a reinstall.
      await secureStorage.read(key: 'password');
    } catch (e) {
      debugPrint("Detected secure storage decryption failure (Keystore wiped). This indicates a reinstall with restored backup! $e");
      isReinstallWithRestoredBackup = true;
      
      // We must clear secure storage to reset the corrupted Keystore state
      try {
        await secureStorage.deleteAll();
      } catch (_) {}
    }

    if (isReinstallWithRestoredBackup) {
      debugPrint("Wiping all local storage (GetStorage, Hive, etc) due to reinstall to guarantee fresh install flow...");
      await storage.erase(); // Wipe GetStorage completely
      // By returning early, we bypass the selective cache restore, ensuring everything stays wiped.
      return;
    }

    // 1. Password Migration (Runs on every boot to ensure no user is left behind)
    final oldPassword = storage.read('password');
    if (oldPassword != null) {
      await secureStorage.write(key: 'password', value: oldPassword);
      await storage.remove('password');
      debugPrint("Password migrated to secure storage.");
    }

    // 2. Version Check for Cache Clearing
    final packageInfo = await PackageInfo.fromPlatform();
    
    final String currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final String? lastVersion = storage.read('last_app_version');

    // If lastVersion is null, it's a fresh install.
    // If it's different from currentVersion, it's an update.
    if (lastVersion != null && lastVersion != currentVersion) {
      debugPrint("App updated from $lastVersion to $currentVersion. Clearing cache...");
      await _selectiveCacheClear(storage);
    }

    // Save the current version for the next time the app opens
    storage.write('last_app_version', currentVersion);
  }

  static Future<void> _selectiveCacheClear(GetStorage storage) async {
    // 1. Read critical data we must NOT lose
    final instanceName = storage.read('instanceName');
    final username = storage.read('username');
    final email = storage.read('email');
    final isLoggedIn = storage.read('isLoggedIn');
    
    // Server & Employee data
    final webLink = storage.read('webLink');
    final empDisplayName = storage.read('empDisplayName');
    final deviceId_v2 = storage.read('deviceId_v2');

    // Biometric flags
    final hasBiometric = storage.read('hasBiometric');
    final biometricEnabled = storage.read('biometricEnabled');
    final biometricSetupComplete = storage.read('biometricSetupComplete');

    // App Preferences (Theme, Language, Privacy, Notifications)
    final isDarkMode = storage.read('isDarkMode');
    final language = storage.read('language');
    final privacyAccepted = storage.read('privacyAccepted');
    final permissionsRequested = storage.read('permissionsRequested');
    final pushNotificationsEnabled = storage.read('pushNotificationsEnabled');
    final notificationPollingEnabled = storage.read('notificationPollingEnabled');
    final notificationPollingInterval = storage.read('notificationPollingInterval');

    // 2. Erase everything in GetStorage
    await storage.erase();

    // 3. Restore the critical data & preferences
    if (instanceName != null) storage.write('instanceName', instanceName);
    if (username != null) storage.write('username', username);
    if (email != null) storage.write('email', email);
    if (isLoggedIn != null) storage.write('isLoggedIn', isLoggedIn);
    
    if (webLink != null) storage.write('webLink', webLink);
    if (empDisplayName != null) storage.write('empDisplayName', empDisplayName);
    if (deviceId_v2 != null) storage.write('deviceId_v2', deviceId_v2);
    
    if (hasBiometric != null) storage.write('hasBiometric', hasBiometric);
    if (biometricEnabled != null) storage.write('biometricEnabled', biometricEnabled);
    if (biometricSetupComplete != null) storage.write('biometricSetupComplete', biometricSetupComplete);

    if (isDarkMode != null) storage.write('isDarkMode', isDarkMode);
    if (language != null) storage.write('language', language);
    if (privacyAccepted != null) storage.write('privacyAccepted', privacyAccepted);
    if (permissionsRequested != null) storage.write('permissionsRequested', permissionsRequested);
    if (pushNotificationsEnabled != null) storage.write('pushNotificationsEnabled', pushNotificationsEnabled);
    if (notificationPollingEnabled != null) storage.write('notificationPollingEnabled', notificationPollingEnabled);
    if (notificationPollingInterval != null) storage.write('notificationPollingInterval', notificationPollingInterval);
  }
}
