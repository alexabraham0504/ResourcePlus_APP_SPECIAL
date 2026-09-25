import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../controllers/language_controller.dart';
import '../../../services/api_service.dart';
import '../../../config/api_endpoints.dart';

class AuthController extends GetxController {
  // State variables
  var instanceName = ''.obs;
  var emailOrPhone = ''.obs;
  var verificationCode = ''.obs;
  var password = ''.obs;
  var newPassword = ''.obs;
  var confirmPassword = ''.obs;
  var isLoading = false.obs;
  var errorMessage = ''.obs;

  final secureStorage = const FlutterSecureStorage();
  final Dio _dio = ApiService().dio;

  // API: Validate Instance
  Future<bool> validateInstance(String instance) async {
    isLoading.value = true;
    errorMessage.value = '';
    // Convert to lowercase for case-insensitive handling
    // final normalizedInstance = instance.toLowerCase().trim();
    await GetStorage().write('instanceName', instance);

    final languageController = Get.find<LanguageController>();

    try {
      final response = await _dio.get(
        ApiEndpoints.checkInstance,
        queryParameters: {
          'instanceName': instance,
          'Lang': languageController.currentLangCode,
        },
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 &&
          response.data is List &&
          response.data.isNotEmpty) {
        final data = response.data[0];
        final isValid = data['IsValid'].toString().toLowerCase() == 'true';
        if (isValid) {
          isLoading.value = false;
          return true;
        } else {
          errorMessage.value = data['RsltMessage'] ?? 'Invalid instance';
        }
      } else {
        errorMessage.value = 'Unexpected response from server.';
      }
    } catch (e) {
      errorMessage.value = 'Network error. Please try again.';
      print(e);
    }
    isLoading.value = false;
    return false;
  }

  Future<bool> validateEmailOrPhone(String value) async {
    await Future.delayed(const Duration(seconds: 1));
    return value.contains('@') || value.length == 10;
  }

  // API: Check Email
  Future<bool> sendVerificationCode(String email) async {
    // Fallback: if empty (e.g. Android 11-14 session loss), read from storage
    if (email.trim().isEmpty) {
      email = (GetStorage().read('email') ?? '').toString();
    }
    if (email.trim().isEmpty) {
      errorMessage.value = 'Email address not found. Please go back and enter your email.';
      return false;
    }
    await GetStorage().write('email', email);
    isLoading.value = true;
    errorMessage.value = '';

    final languageController = Get.find<LanguageController>();
    // Get the current instance name from storage to ensure it's up to date
    final currentInstanceName =
        await GetStorage().read('instanceName') ?? instanceName.value;

    try {
      final response = await _dio.get(
        ApiEndpoints.checkEmail,
        queryParameters: {
          'instanceName': currentInstanceName,
          'usrEmail': email,
          'Lang': languageController.currentLangCode,
        },
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 &&
          response.data is List &&
          response.data.isNotEmpty) {
        final data = response.data[0];
        final isValid = data['IsValid'].toString().toLowerCase() == 'true';
        if (isValid) {
          isLoading.value = false;
          return true;
        } else {
          errorMessage.value = data['RsltMessage'] ?? 'Invalid email address';
        }
      } else {
        errorMessage.value = 'Unexpected response from server.';
      }
    } catch (e) {
      errorMessage.value = 'Network error. Please try again.';
    }
    isLoading.value = false;
    return false;
  }

  // API: Verify OTP
  Future<bool> validateVerificationCode(String otp) async {
    isLoading.value = true;
    errorMessage.value = '';

    final languageController = Get.find<LanguageController>();

    // Read from storage as fallback if controller values are empty (fixes Android 11-14 session loss)
    final effectiveInstance = instanceName.value.isNotEmpty
        ? instanceName.value
        : (GetStorage().read('instanceName') ?? '').toString();
    final effectiveEmail = emailOrPhone.value.isNotEmpty
        ? emailOrPhone.value
        : (GetStorage().read('email') ?? '').toString();

    try {
      final response = await _dio.get(
        ApiEndpoints.verifyOtp,
        queryParameters: {
          'instanceName': effectiveInstance,
          'usrEmail': effectiveEmail,
          'loginOTP': otp,
          'Lang': languageController.currentLangCode,
        },
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 &&
          response.data is List &&
          response.data.isNotEmpty) {
        final data = response.data[0];
        final isValid = data['IsValid'].toString().toLowerCase() == 'true';
        if (isValid) {
          isLoading.value = false;
          return true;
        } else {
          errorMessage.value = data['RsltMessage'] ?? 'Invalid OTP';
        }
      } else {
        errorMessage.value = 'Unexpected response from server.';
      }
    } catch (e) {
      errorMessage.value = 'Network error. Please try again.';
    }
    isLoading.value = false;
    return false;
  }

  // API: Validate User Login
  Future<Map<String, dynamic>> validateUserLogin(String password) async {
    isLoading.value = true;
    errorMessage.value = '';

    final languageController = Get.find<LanguageController>();

    // Read from storage as fallback if controller values are empty (fixes Android 11-14 session loss)
    final effectiveInstance = instanceName.value.isNotEmpty
        ? instanceName.value
        : (GetStorage().read('instanceName') ?? '').toString();
    final effectiveEmail = emailOrPhone.value.isNotEmpty
        ? emailOrPhone.value
        : (GetStorage().read('email') ?? '').toString();

    print('DEBUG: [validateUserLogin] resolved effectiveInstance=$effectiveInstance, effectiveEmail=$effectiveEmail');
    try {
      print('DEBUG: [validateUserLogin] Sending validateUser request to ${ApiEndpoints.validateUser}');
      final response = await _dio.get(
        ApiEndpoints.validateUser,
        queryParameters: {
          'instanceName': effectiveInstance,
          'usrEmail': effectiveEmail,
          'UsrPassword': password,
          'Lang': languageController.currentLangCode,
        },
        options: Options(responseType: ResponseType.json),
      );

      print('DEBUG: [validateUserLogin] Response status=${response.statusCode}, data=${response.data}');
      if (response.statusCode == 200 &&
          response.data is List &&
          response.data.isNotEmpty) {
        final data = response.data[0];
        final isValid = data['IsValid'].toString().toLowerCase() == 'true';
        if (isValid) {
          print('DEBUG: [validateUserLogin] Validation successful!');
          // Store user data for biometric login
          await GetStorage().write('webLink', data['ClientUrl'] ?? '');
          await GetStorage().write(
            'empDisplayName',
            data['EmpDisplayName'] ?? '',
          );
          await GetStorage().write('username', data['Username'] ?? '');
          await GetStorage().write('email', data['Email'] ?? '');
          await GetStorage().write('lastLoginTime', DateTime.now().toIso8601String());
          await secureStorage.write(key: 'password', value: password); // Store password for biometric login
          await GetStorage().write('instanceName', effectiveInstance);
          
          // Phase 2: Upload FCM Device Token to Backend
          try {
            String? fcmToken = await FirebaseMessaging.instance.getToken();
            
            // Print the token to the terminal so Alex can copy it and send it to Ma'am
            print("\n\n====== MY FCM TOKEN ======");
            print(fcmToken);
            print("==========================\n\n");

            if (fcmToken != null) {
              await _dio.post(
                ApiEndpoints.updateDeviceToken,
                data: {
                  'InstanceName': effectiveInstance,
                  'UsrEmail': data['Email'] ?? '',
                  'DeviceToken': fcmToken,
                  'DeviceOS': Platform.isIOS ? 'iOS' : 'Android'
                },
              );
              print('DEBUG: Successfully sent FCM Token to backend!');
            }
          } catch (e) {
            print('DEBUG: Failed to send FCM Token to backend: $e');
          }

          isLoading.value = false;
          return {
            'success': true,
            'isNeedToResetPwd': data['IsNeedToResetPwd'] ?? false,
            'empDisplayName': data['EmpDisplayName'] ?? '',
            'username': data['Username'] ?? '',
            'email': data['Email'] ?? '',
            'clientUrl': data['ClientUrl'] ?? '',
            'message': data['RsltMessage'] ?? 'Authentication successful',
          };
        } else {
          print('DEBUG: [validateUserLogin] Validation failed. RsltMessage=${data['RsltMessage']}');
          errorMessage.value = data['RsltMessage'] ?? 'Invalid credentials';
          isLoading.value = false;
          return {
            'success': false,
            'message': data['RsltMessage'] ?? 'Invalid credentials',
          };
        }
      } else {
        print('DEBUG: [validateUserLogin] Unexpected response: status=${response.statusCode}, data=${response.data}');
        errorMessage.value = 'Unexpected response from server.';
        isLoading.value = false;
        return {
          'success': false,
          'message': 'Unexpected response from server.',
        };
      }
    } catch (e) {
      print('DEBUG: [validateUserLogin] Network error exception: $e');
      errorMessage.value = 'Network error. Please try again.';
      isLoading.value = false;
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  // API: Change Password
  Future<Map<String, dynamic>> changeUserPassword(String newPassword) async {
    isLoading.value = true;
    errorMessage.value = '';

    final languageController = Get.find<LanguageController>();

    // Get instance name and email from storage (more reliable than controller values)
    final storedInstanceName =
        GetStorage().read('instanceName') ?? instanceName.value;
    final storedEmail = GetStorage().read('email') ?? emailOrPhone.value;

    if (storedInstanceName == null || storedInstanceName.toString().isEmpty) {
      isLoading.value = false;
      return {
        'success': false,
        'message': 'Instance not found. Please login again.',
      };
    }

    if (storedEmail == null || storedEmail.toString().isEmpty) {
      isLoading.value = false;
      return {
        'success': false,
        'message': 'Email not found. Please login again.',
      };
    }

    try {
      final response = await _dio.get(
        ApiEndpoints.changePwd,
        queryParameters: {
          'instanceName': storedInstanceName,
          'usrEmail': storedEmail,
          'UsrPassword': newPassword,
          'Lang': languageController.currentLangCode,
        },
        options: Options(responseType: ResponseType.json),
      );
      // Debug: Print the actual response
      print('Change Password API Response Status: ${response.statusCode}');
      print('Change Password API Response Data: ${response.data}');
      print('Response Data Type: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        // Handle different response formats
        dynamic data;

        if (response.data is List) {
          if (response.data.isNotEmpty) {
            // Original format: List with first element
            data = response.data[0];
            print('Using List format - First element: $data');
          } else {
            // Empty array - treat as error unless API documentation says otherwise
            print('Empty array response - treating as error');
            isLoading.value = false;
            return {
              'success': false,
              'message': 'Invalid response from server. Please try again.',
            };
          }
        } else if (response.data is Map) {
          // Direct Map format
          data = response.data;
          print('Using Map format: $data');
        } else {
          // Handle other formats
          print('Unexpected response format: ${response.data}');
          errorMessage.value = 'Unexpected response format from server.';
          isLoading.value = false;
          return {
            'success': false,
            'message': 'Unexpected response format from server.',
          };
        }

        // Check if data contains the expected fields
        if (data is Map && data.containsKey('IsValid')) {
          // Handle both boolean and string 'true'/'True' values
          final isValidValue = data['IsValid'];
          final isValid =
              isValidValue == true ||
              isValidValue.toString().toLowerCase() == 'true';
          print(
            'IsValid (raw): $isValidValue, IsValid (parsed): $isValid, RsltMessage: ${data['RsltMessage']}',
          );

          if (isValid) {
            isLoading.value = false;
            return {
              'success': true,
              'message': data['RsltMessage'] ?? 'Password changed successfully',
            };
          } else {
            errorMessage.value =
                data['RsltMessage'] ?? 'Password change failed';
            isLoading.value = false;
            return {
              'success': false,
              'message': data['RsltMessage'] ?? 'Password change failed',
            };
          }
        } else {
          print(
            'Response missing IsValid field. Available keys: ${data is Map ? data.keys.toList() : 'Not a Map'}',
          );
          errorMessage.value = 'Response missing required fields.';
          isLoading.value = false;
          return {
            'success': false,
            'message': 'Response missing required fields.',
          };
        }
      } else {
        errorMessage.value =
            'Server returned status code: ${response.statusCode}';
        isLoading.value = false;
        return {
          'success': false,
          'message': 'Server returned status code: ${response.statusCode}',
        };
      }
    } catch (e) {
      errorMessage.value = 'Network error. Please try again.';
      isLoading.value = false;
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  Future<bool> validatePassword(String password) async {
    final result = await validateUserLogin(password);
    if (result['success']) {
      this.password.value = password;
      return true;
    }
    return false;
  }

  Future<bool> changePassword(String newPassword) async {
    final result = await changeUserPassword(newPassword);
    if (result['success']) {
      this.newPassword.value = newPassword;
      return true;
    }
    return false;
  }

  Future<bool> linkBiometric() async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  // Check if biometric setup is complete
  bool isBiometricSetupComplete() {
    return GetStorage().read('biometricSetupComplete') ?? false;
  }

  // Check if biometric login is enabled
  bool isBiometricEnabled() {
    return GetStorage().read('biometricEnabled') ?? false;
  }

  // Biometric Authentication
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Getter to access LocalAuthentication for debugging
  LocalAuthentication get localAuth => _localAuth;

  Future<bool> isBiometricAvailable() async {
    try {
      // NOTE: canCheckBiometrics is deprecated and returns false on Android 12+ (Samsung A16 etc)
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      print('Debug: isDeviceSupported: $isDeviceSupported');
      print('Debug: availableBiometrics: $availableBiometrics');

      return isDeviceSupported && availableBiometrics.isNotEmpty;
    } catch (e) {
      print('Debug: Biometric availability error: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      print('Debug: Starting biometric authentication...');

      final isAvailable = await isBiometricAvailable();
      print('Debug: Biometric available: $isAvailable');
      if (!isAvailable) {
        print('Debug: Biometric not available, aborting');
        return false;
      }

      final availableBiometrics = await getAvailableBiometrics();
      print('Debug: Available biometrics: $availableBiometrics');
      if (availableBiometrics.isEmpty) {
        print('Debug: No biometrics enrolled, aborting');
        return false;
      }

      print('Debug: Calling _localAuth.authenticate...');

      // Try different authentication options
      // On Android 12+, we MUST set biometricOnly: true to prevent Samsung from showing a PIN dialog
      // We also don't filter by type anymore because Android 15 Samsung returns BiometricType.strong
      print('Debug: Using generic biometric authentication (biometricOnly: true)');
      const authOptions = AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
        sensitiveTransaction: false,
      );

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to set up biometric login',
        options: authOptions,
      );

      print('Debug: Authentication result: $authenticated');
      return authenticated;
    } catch (e) {
      print('Debug: Biometric authentication error: $e');
      print('Debug: Error type: ${e.runtimeType}');
      print('Debug: Error details: ${e.toString()}');

      // Handle specific platform exceptions
      if (e.toString().contains('no_fragment_activity')) {
        print(
          'Debug: FragmentActivity error - MainActivity needs to extend FlutterFragmentActivity',
        );
      } else if (e.toString().contains('NotAvailable')) {
        print('Debug: Biometric hardware not available');
      } else if (e.toString().contains('NotEnrolled')) {
        print('Debug: No biometrics enrolled on device');
      } else if (e.toString().contains('UserCancel')) {
        print('Debug: User cancelled biometric authentication');
      }

      return false;
    }
  }

  Future<Map<String, dynamic>> biometricLogin() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Check if biometric authentication is available
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        isLoading.value = false;
        return {
          'success': false,
          'message':
              'Biometric authentication is not available on this device.',
        };
      }

      // Authenticate with biometrics
      final authenticated = await authenticateWithBiometrics();
      if (!authenticated) {
        isLoading.value = false;
        return {
          'success': false,
          'message': 'Biometric authentication failed.',
        };
      }

      // Get stored credentials for biometric login
      final storedEmail = GetStorage().read('email');
      final storedPassword = await secureStorage.read(key: 'password');

      if (storedEmail == null || storedPassword == null) {
        isLoading.value = false;
        return {
          'success': false,
          'message':
              'No stored credentials found. Please login with username and password first.',
        };
      }

      // Perform login with stored credentials
      final loginResult = await loginWithStoredInstance(
        storedEmail,
        storedPassword,
      );

      return loginResult;
    } catch (e) {
      isLoading.value = false;
      return {
        'success': false,
        'message': 'Biometric login failed. Please try again.',
      };
    }
  }

  Future<String> getDynamicUrl() async {
    await Future.delayed(const Duration(seconds: 1));
    return 'https://example.com';
  }

  // Logout method
  Future<void> logout() async {
    // Clear all stored data except instance name
    // Also clear biometric settings so user must setup again after logout
    await GetStorage().write('isLoggedIn', false);
    await GetStorage().write('email', '');
    await secureStorage.delete(key: 'password');
    await GetStorage().write('username', '');
    await GetStorage().write('empDisplayName', '');
    await GetStorage().write('webLink', '');
    await GetStorage().remove('hasBiometric');
    await GetStorage().remove('biometricEnabled');
    await GetStorage().remove('biometricSetupComplete');

    // Reset controller values
    emailOrPhone.value = '';
    password.value = '';
    newPassword.value = '';
    confirmPassword.value = '';
    verificationCode.value = '';
    errorMessage.value = '';
  }

  // API: Login with stored instance
  Future<Map<String, dynamic>> loginWithStoredInstance(
    String email,
    String password,
  ) async {
    print('DEBUG: loginWithStoredInstance called with email=$email');
    isLoading.value = true;
    errorMessage.value = '';

    // Get instance name from storage
    final storedInstanceName = GetStorage().read('instanceName');
    print('DEBUG: storedInstanceName=$storedInstanceName');
    if (storedInstanceName == null || storedInstanceName.toString().isEmpty) {
      print('DEBUG: storedInstanceName is empty or null');
      isLoading.value = false;
      return {
        'success': false,
        'message': 'Instance not found. Please scan instance first.',
      };
    }

    final languageController = Get.find<LanguageController>();

    try {
      print('DEBUG: Sending validateUser request to ${ApiEndpoints.validateUser}');
      final response = await _dio.get(
        ApiEndpoints.validateUser,
        queryParameters: {
          'instanceName': storedInstanceName,
          'usrEmail': email,
          'UsrPassword': password,
          'Lang': languageController.currentLangCode,
        },
        options: Options(responseType: ResponseType.json),
      );

      print('DEBUG: Response status=${response.statusCode}, data=${response.data}');

      if (response.statusCode == 200 &&
          response.data is List &&
          response.data.isNotEmpty) {
        final data = response.data[0];
        final isValid = data['IsValid'].toString().toLowerCase() == 'true';

        if (isValid) {
          print('DEBUG: Login validation successful!');
          // Store user data
          await GetStorage().write('webLink', data['ClientUrl'] ?? '');
          await GetStorage().write(
            'empDisplayName',
            data['EmpDisplayName'] ?? '',
          );
          await GetStorage().write('username', data['Username'] ?? '');
          await GetStorage().write('email', data['Email'] ?? '');
          await GetStorage().write('lastLoginTime', DateTime.now().toIso8601String());
          await secureStorage.write(
            key: 'password',
            value: password,
          ); // Store password for biometric login

          isLoading.value = false;
          return {
            'success': true,
            'isNeedToResetPwd': data['IsNeedToResetPwd'] ?? false,
            'empDisplayName': data['EmpDisplayName'] ?? '',
            'username': data['Username'] ?? '',
            'email': data['Email'] ?? '',
            'clientUrl': data['ClientUrl'] ?? '',
            'message': data['RsltMessage'] ?? 'Authentication successful',
          };
        } else {
          print('DEBUG: Login validation failed. RsltMessage=${data['RsltMessage']}');
          errorMessage.value = data['RsltMessage'] ?? 'Invalid credentials';
          isLoading.value = false;
          return {
            'success': false,
            'message': data['RsltMessage'] ?? 'Invalid credentials',
          };
        }
      } else {
        print('DEBUG: Unexpected response data: status=${response.statusCode}, isList=${response.data is List}');
        errorMessage.value = 'Unexpected response from server.';
        isLoading.value = false;
        return {
          'success': false,
          'message': 'Unexpected response from server.',
        };
      }
    } catch (e) {
      print('DEBUG: Login error exception: $e');
      errorMessage.value = 'Network error. Please try again.';
      isLoading.value = false;
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }
}
