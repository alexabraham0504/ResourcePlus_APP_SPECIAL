import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../controllers/language_controller.dart';
import '../../../services/notification_service.dart';
import '../../../services/api_service.dart';
import '../../../config/api_endpoints.dart';
import '../../../routes/app_routes.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../views/tabs/attendance_tab.dart';

class HomeController extends GetxController with GetSingleTickerProviderStateMixin, WidgetsBindingObserver {
  final Dio _dio = ApiService().dio;
  final NotificationService _notificationService = NotificationService();

  // Scaffold key for drawer control
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  // ZoomDrawer Controller
  final ZoomDrawerController zoomDrawerController = ZoomDrawerController();

  // Navigation index
  final RxInt currentIndex = 0.obs;

  // Home data
  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  // Employee details
  final RxString empNumber = ''.obs;
  final RxString employeeName = ''.obs;
  final RxString positionName = ''.obs;

  // Dashboard data
  final RxList dashboardData = <Map<String, dynamic>>[].obs;

  // Static contents
  final RxMap<String, String> staticContents = <String, String>{}.obs;

  // Attendance data
  final RxBool isAttendanceLoading = false.obs;
  final RxBool hasAttendanceError = false.obs;
  final RxString attendanceErrorMessage = ''.obs;

  // Attendance Rate
  final RxList attendanceRate = <Map<String, dynamic>>[].obs;

  // Attendance Counts
  final RxList attendanceCounts = <Map<String, dynamic>>[].obs;

  // Recent Activities
  final RxList recentActivities = <Map<String, dynamic>>[].obs;

  // Attendance filter & display count (client-side)
  final RxString attendanceFilter = 'All'.obs; // 'All', 'Present', 'Absent', 'Late', 'Early', 'Week End', etc.
  final RxInt attendanceDisplayCount = 6.obs; // default 6, user can pick 10, 20, 50

  // Legends
  final RxList legends = <Map<String, dynamic>>[].obs;

  // Attendance Static Contents
  final RxMap<String, String> attendanceStaticContents = <String, String>{}.obs;

  // Profile data
  final RxBool isProfileLoading = false.obs;
  final RxBool hasProfileError = false.obs;
  final RxString profileErrorMessage = ''.obs;

  // Contact Information
  final RxString profileEmpNumber = ''.obs;
  final RxString profileEmployeeName = ''.obs;
  final RxString profileEmpEmail = ''.obs;
  final RxString profileEmpMobile = ''.obs;

  // Work Information
  final RxList workInformation = <Map<String, dynamic>>[].obs;

  // Skills
  final RxList skills = <Map<String, dynamic>>[].obs;

  // Certifications
  final RxList certifications = <Map<String, dynamic>>[].obs;

  // Profile Static Contents
  final RxMap<String, String> profileStaticContents = <String, String>{}.obs;

  // Notification data
  final RxBool isNotificationLoading = false.obs;
  final RxBool hasNotificationError = false.obs;
  final RxString notificationErrorMessage = ''.obs;

  // Notifications list
  final RxList notifications = <Map<String, dynamic>>[].obs;

  // Unread notifications count getter
  int get unreadNotificationsCount {
    int unreadCount = 0;
    for (var notif in notifications) {
      final readStatus = notif['ReadStatus'] ?? notif['IsRead'] ?? notif['isRead'];
      final isRead = readStatus == 'True' || readStatus == 'true' || readStatus == 1 || readStatus == true;
      if (!isRead) {
        unreadCount++;
      }
    }
    return unreadCount;
  }

  // Notification Static Contents
  final RxMap<String, String> notificationStaticContents =
      <String, String>{}.obs;

  // Common Contents (for base URL)
  final RxMap<String, String> commonContents = <String, String>{}.obs;

  // Settings data
  final RxBool isSettingsLoading = false.obs;
  final RxBool hasSettingsError = false.obs;
  final RxString settingsErrorMessage = ''.obs;

  // Settings Static Contents
  final RxMap<String, String> settingsStaticContents = <String, String>{}.obs;

  // Profile Picture
  final RxString profilePictureUrl = ''.obs;

  // Notification polling
  Timer? _notificationTimer;
  final RxBool isPollingEnabled = true.obs;
  final RxInt pollingIntervalMinutes = 2.obs; // Check every 2 minutes
  final RxBool isPollingActive = false.obs;
  final RxBool pushNotificationsEnabled = true.obs;

  // Cached portal URL for faster HR Portal loading
  final cachedPortalUrl = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Start all core data fetches concurrently in the background
    // This dramatically reduces perceived load time when navigating tabs
    fetchHomeData();
    fetchAttendanceData();
    fetchProfileData();
    fetchNotificationData(); // Re-enabled so it loads automatically!
    fetchSettingsData();
    
    initializeProfilePicture();
    _loadPollingSettings();
    // Listen for app lifecycle changes to refresh data on resume
    WidgetsBinding.instance.addObserver(this);
  }

  // Tracks when the app went to background to avoid triggering biometric
  // for brief interruptions like pulling down the notification shade.
  DateTime? _backgroundedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Record when the app went to background
      _backgroundedAt ??= DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      final secondsInBackground = _backgroundedAt == null
          ? 0
          : DateTime.now().difference(_backgroundedAt!).inSeconds;
      _backgroundedAt = null; // reset

      // 1. Check if biometric is required on resume.
      // Only trigger if the app was TRULY in background for >30 seconds.
      // This prevents the biometric screen from appearing when the user
      // simply swipes down the notification bar and releases it.
      const int biometricTimeoutSeconds = 30;

      if (secondsInBackground >= biometricTimeoutSeconds) {
        final storage = GetStorage();
        final hasBiometric = storage.read('hasBiometric');
        final biometricEnabled = storage.read('biometricEnabled') == true;
        final biometricSetupComplete = storage.read('biometricSetupComplete') == true;
        
        final currentRoute = Get.currentRoute;
        // Do not trigger global biometric lock if we are already doing a biometric check 
        // for attendance! Doing so crashes Android due to overlapping BiometricPrompt fragments.
        if (hasBiometric == true && 
            biometricEnabled && 
            biometricSetupComplete && 
            currentRoute != AppRoutes.biometricCheck &&
            currentRoute != AppRoutes.biometricLink &&
            currentRoute != AppRoutes.fingerprintPunch) {
          Get.toNamed(AppRoutes.biometricCheck, arguments: {'isFromResume': true});
        }
      }

      // 2. Refresh the current page silently to prevent lag
      if (currentIndex.value == 0) {
        fetchHomeData(silent: true);
      } else if (currentIndex.value == 1) {
        fetchAttendanceData(silent: true);
      } else if (currentIndex.value == 3) {
        fetchProfileData(silent: true);
      } else if (currentIndex.value == 4) {
        fetchSettingsData(silent: true);
      }
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    // _stopNotificationPolling();
    super.onClose();
  }

  void changeTab(int index) {
    currentIndex.value = index;
    // Always silently refresh the attendance tab when the user taps on it
    if (index == 1) {
      fetchAttendanceData(silent: true);
    }
    if (index == 0) {
      fetchHomeData(silent: true);
    }
    if (index == 3 && profileEmpNumber.value.isEmpty) {
      fetchProfileData();
    }
    if (index == 4 && settingsStaticContents.isEmpty) {
      fetchSettingsData();
    }
  }

  Future<void> openTodayPunches(BuildContext context) async {
    // 1. Switch to Attendance Tab first!
    changeTab(1);
    await Future.delayed(const Duration(milliseconds: 300));
    
    final today = DateTime.now();
    final todayStr = DateFormat('dd/MM/yyyy').format(today);
    final apiDate = DateFormat('MM/dd/yyyy').format(today);
    
    // 1. Try to find today's records in recentActivities first (which uses dd/MM/yyyy)
    final todayRecords = recentActivities.where((r) {
      return (r['AttDate'] ?? '').toString() == todayStr || (r['AttDate'] ?? '').toString() == apiDate;
    }).cast<Map<String, dynamic>>().toList();
    
    if (todayRecords.isEmpty) {
      Get.snackbar('No Data', 'No attendance records found for today.', backgroundColor: Colors.orange.withOpacity(0.8), colorText: Colors.white);
      return;
    }
    
    // 2. Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    
    // 3. Fetch raw punches
    final formattedApiDate = DateFormat('yyyy-MM-dd').format(today);
    final rawPunches = await fetchPunchesForDate(formattedApiDate);
    
    if (rawPunches.isNotEmpty) {
      final summary = todayRecords.first;
      final inAddr = summary['CheckINAddr']?.toString() ?? '';
      final outAddr = summary['CheckoutAddr']?.toString() ?? '';
      final fallbackLoc = summary['Location']?.toString() ?? summary['locationinfo']?.toString() ?? '';
      
      for (var punch in rawPunches) {
        final type = punch['Type']?.toString().toUpperCase() ?? '';
        if (type == 'IN' && inAddr.isNotEmpty) punch['CheckINAddr'] = inAddr;
        else if (type == 'OUT' && outAddr.isNotEmpty) punch['CheckoutAddr'] = outAddr;
        if (fallbackLoc.isNotEmpty) punch['Location'] = fallbackLoc;
      }
    }
    
    // 4. Close loading & show bottom sheet
    Navigator.pop(context);
    AttendanceTab.showPunchesBottomSheet(context, todayRecords, rawPunches.isNotEmpty ? rawPunches.cast<Map<String, dynamic>>() : todayRecords);
  }

  Future<void> fetchHomeData({bool silent = false}) async {
    try {
      final storage = GetStorage();
      if (!silent) {
        final cachedData = storage.read('cachedHomeData');
        if (cachedData != null) {
          _parseHomeData(cachedData);
          silent = true;
        } else {
          isLoading.value = true;
        }
      }
      hasError.value = false;
      errorMessage.value = '';

      String instanceName = storage.read('instanceName') ?? '';
      String userName = storage.read('username') ?? '';
      String userEmail = storage.read('email') ?? '';
      
      String usrEmailValue = userName.isNotEmpty ? userName : userEmail;

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getHomeData,
        queryParameters: {
          'instanceName': instanceName,
          'Usremail': usrEmailValue,
          'Lang': languageController.currentLangCode,
        },
      );

      if (response.statusCode == 200) {
        storage.write('cachedHomeData', response.data);
        _parseHomeData(response.data);
      }
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Failed to load home data: ${e.toString()}';
      print('Error fetching home data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _parseHomeData(dynamic data) {
    if (data == null) return;
    // Parse employee details
        if (data['EmployeeDetails'] != null) {
          try {
            final empDetails = data['EmployeeDetails'];
            print('EmployeeDetails type: ${empDetails.runtimeType}');
            print('EmployeeDetails value: $empDetails');
            
            // Fetch and print FCM Token right on startup so Alex can easily copy it
            FirebaseMessaging.instance.getToken().then((token) {
              print("\n\n====== MY FCM TOKEN ======");
              print(token);
              print("==========================\n\n");
            }).catchError((e) {
              print('Failed to fetch token on home load: $e');
            });

            if (empDetails is Map<String, dynamic>) {
              empNumber.value = empDetails['Emp_Number']?.toString() ?? '';
              employeeName.value = empDetails['EmployeeName']?.toString() ?? '';
              positionName.value = empDetails['PositionName']?.toString() ?? '';
            } else if (empDetails is List && empDetails.isNotEmpty) {
              // Handle case where EmployeeDetails might be a list
              final firstItem = empDetails[0];
              if (firstItem is Map<String, dynamic>) {
                empNumber.value = firstItem['Emp_Number']?.toString() ?? '';
                employeeName.value =
                    firstItem['EmployeeName']?.toString() ?? '';
                positionName.value =
                    firstItem['PositionName']?.toString() ?? '';
              }
            } else {
              print('Unexpected EmployeeDetails structure: $empDetails');
            }
          } catch (e) {
            print('Error parsing employee details: $e');
            empNumber.value = '';
            employeeName.value = '';
            positionName.value = '';
          }
        }

        // Parse dashboard data
        if (data['DashboardData'] != null) {
          try {
            final dashboardList = data['DashboardData'] as List;
            final parsedDashboard = <Map<String, dynamic>>[];

            for (final item in dashboardList) {
              if (item is Map<String, dynamic>) {
                parsedDashboard.add(item);
              }
            }

            dashboardData.value = parsedDashboard;
          } catch (e) {
            print('Error parsing dashboard data: $e');
            dashboardData.value = [];
          }
        }

        // Parse static contents
        if (data['StaticContents'] != null) {
          try {
            final contents = data['StaticContents'] as List;
            final tempContents = <String, String>{};

            for (final content in contents) {
              if (content is Map<String, dynamic>) {
                final contentType = content['ContentType']?.toString();
                final contentText = content['ContentText']?.toString() ?? '';

                if (contentType != null) {
                  tempContents[contentType] = contentText;
                }
              }
            }

            staticContents.value = tempContents;
          } catch (e) {
            print('Error parsing static contents: $e');
            staticContents.value = {};
          }
        }
  }

  void refreshData() {
    fetchHomeData();
  }

  Future<void> fetchAttendanceData({bool silent = false}) async {
    try {
      final storage = GetStorage();
      if (!silent) {
        final cachedData = storage.read('cachedAttendanceData');
        if (cachedData != null) {
          _parseAttendanceData(cachedData);
          silent = true;
        } else {
          isAttendanceLoading.value = true;
        }
      }
      hasAttendanceError.value = false;
      attendanceErrorMessage.value = '';

      String instanceName = storage.read('instanceName') ?? '';
      String userName = storage.read('username') ?? '';
      String userEmail = storage.read('email') ?? '';
      
      String usrEmailValue = userName.isNotEmpty ? userName : userEmail;

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getAttData,
        queryParameters: {
          'instanceName': instanceName,
          'Usremail': usrEmailValue,
          'Lang': languageController.currentLangCode,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        storage.write('cachedAttendanceData', response.data);
        
        try {
          final rawJsonStr = jsonEncode(response.data);
          final lowerJson = rawJsonStr.toLowerCase();
          print('--- RAW JSON OUTPUT START ---');
          print('Does raw JSON contain "punchimagebyte"? ${lowerJson.contains('punchimagebyte')}');
          print('Does raw JSON contain "selfie"? ${lowerJson.contains('selfie')}');
          if (lowerJson.contains('punchimagebyte')) {
            print('YES! The backend IS sending the base64 string somewhere! We just need to find it.');
          }
          print('RAW_JSON_LENGTH: ${rawJsonStr.length}');
          // If the image is there, print the first few chunks
          if (lowerJson.contains('punchimagebyte') || rawJsonStr.length < 5000) {
            final chunks = (rawJsonStr.length / 800).ceil();
            for(var i=0; i< (chunks > 10 ? 10 : chunks); i++) {
              int start = i * 800;
              int end = (start + 800 < rawJsonStr.length) ? start + 800 : rawJsonStr.length;
              print('JSON_CHUNK_$i: ${rawJsonStr.substring(start, end)}');
            }
          }
          print('--- RAW JSON OUTPUT END ---');
        } catch(e) {}

        _parseAttendanceData(response.data);
      }
    } on DioException catch (e) {
      hasAttendanceError.value = true;
      attendanceErrorMessage.value = 'Failed to load attendance data: ${e.response?.statusCode}';
      print('DioException in fetchAttendanceData: ${e.response?.statusCode} - ${e.response?.data}');
    } catch (e) {
      hasAttendanceError.value = true;
      attendanceErrorMessage.value = 'Failed to load attendance data: ${e.toString()}';
      print('Error fetching attendance data: $e');
    } finally {
      isAttendanceLoading.value = false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPunchesForDate(String dateStr) async {
    try {
      final storage = GetStorage();
      String instanceName = storage.read('instanceName') ?? '';
      String userName = storage.read('username') ?? '';
      String userEmail = storage.read('email') ?? '';
      String usrEmailValue = userName.isNotEmpty ? userName : userEmail;
      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getAttendancePunchData,
        queryParameters: {
          'usrEmail': usrEmailValue,
          'instanceName': instanceName,
          'Lang': languageController.currentLangCode,
          'Date': dateStr,
        },
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (_) {}
        }
        
        try {
          final rawJsonStr = jsonEncode(data);
          final lowerJson = rawJsonStr.toLowerCase();
          print('--- RAW JSON OUTPUT START (GetAttendancePunchData) ---');
          print('Does raw JSON contain "punchimagebyte"? ${lowerJson.contains('punchimagebyte')}');
          if (lowerJson.contains('punchimagebyte')) {
            print('YES! The backend IS sending the base64 string in the NEW API! We just need to find it.');
          } else {
            print('NO! The backend is STILL NOT sending punchimagebyte in the NEW API.');
          }
          print('--- RAW JSON OUTPUT END ---');
        } catch(e) {}

        if (data is List) {
          return List<Map<String, dynamic>>.from(data.whereType<Map>().map((x) => Map<String, dynamic>.from(x)));
        } else if (data is Map) {
          // If the backend wraps it in a data field or similar
          if (data.containsKey('data') && data['data'] is List) {
            return List<Map<String, dynamic>>.from((data['data'] as List).whereType<Map>().map((x) => Map<String, dynamic>.from(x)));
          } else if (data.containsKey('Data') && data['Data'] is List) {
            return List<Map<String, dynamic>>.from((data['Data'] as List).whereType<Map>().map((x) => Map<String, dynamic>.from(x)));
          }
          
          // First try to look for explicit rawPunches or Punches keys
          if (data.containsKey('rawPunches') && data['rawPunches'] is List) {
            return List<Map<String, dynamic>>.from((data['rawPunches'] as List).whereType<Map>().map((x) => Map<String, dynamic>.from(x)));
          } else if (data.containsKey('Punches') && data['Punches'] is List) {
            return List<Map<String, dynamic>>.from((data['Punches'] as List).whereType<Map>().map((x) => Map<String, dynamic>.from(x)));
          }
          
          // Look for any value that is a List of Maps (fallback)
          for (var key in data.keys) {
            if (key.toLowerCase().contains('summary')) continue; // skip summary list
            var value = data[key];
            if (value is List && value.isNotEmpty && value.first is Map) {
              return List<Map<String, dynamic>>.from(value.whereType<Map>().map((x) => Map<String, dynamic>.from(x)));
            }
          }
        }
        
        Get.snackbar('Notice', 'API returned success but no recognizable punch list. Type: ${data.runtimeType}', 
            snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 5));
      } else if (response.statusCode == 204) {
        return [];
      } else {
        Get.snackbar('Error', 'Failed to fetch punches. Status: ${response.statusCode}', 
            snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 5));
      }
    } catch (e) {
      String url = '';
      String errorMsg = e.toString();
      if (e is DioException) {
        url = e.requestOptions.uri.toString();
        print('DioException [${e.response?.statusCode}]: ${e.response?.data}');
        errorMsg = 'Status ${e.response?.statusCode}: ${e.response?.data}';
      }
      print('Error fetching punches for date $dateStr: $e\nURL: $url');
      Get.snackbar('Error 400', 'URL: $url\nResp: $errorMsg', 
          snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 12));
    }
    return [];
  }

  void _parseAttendanceData(dynamic data) {
    if (data == null || (data is String && data.isEmpty) || data == "") return;
    // If it's a string that contains JSON, try decoding it
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (e) {
        return; // If it's not valid JSON, just return
      }
    }
    // Now verify it's a map before proceeding
    if (data is! Map) return;
    
    // Parse Attendance Rate
        if (data['Attendance Rate'] != null) {
          try {
            final rateList = data['Attendance Rate'] as List;
            final parsedRate = <Map<String, dynamic>>[];

            for (final item in rateList) {
              if (item is Map<String, dynamic>) {
                parsedRate.add(item);
              }
            }

            attendanceRate.value = parsedRate;
          } catch (e) {
            print('Error parsing attendance rate: $e');
            attendanceRate.value = [];
          }
        }

        // Parse Attendance Counts
        if (data['Attendance Counts'] != null) {
          try {
            final countsList = data['Attendance Counts'] as List;
            final parsedCounts = <Map<String, dynamic>>[];

            for (final item in countsList) {
              if (item is Map<String, dynamic>) {
                parsedCounts.add(item);
              }
            }

            attendanceCounts.value = parsedCounts;
          } catch (e) {
            print('Error parsing attendance counts: $e');
            attendanceCounts.value = [];
          }
        }

        // Parse Recent Activities
        if (data['Recent Activites'] != null) {
          try {
            final activitiesList = data['Recent Activites'] as List;
            final parsedActivities = <Map<String, dynamic>>[];
            final seenActivities = <String>{};

            for (final item in activitiesList) {
              if (item is Map<String, dynamic>) {
                // DEBUG: print keys of first record to verify API fields
                if (parsedActivities.isEmpty) {
                  print('ATT RECORD KEYS: ${item.keys.toList()}');
                  print('ATT punch_image: ${item['punch_image']}');
                  print('ATT PunchImageByte length: ${(item['PunchImageByte'] ?? item['punch_image_byte'] ?? '').toString().length}');
                }
                // Create a unique key based on date and times to filter out duplicates
                final date = item['AttDate'] ?? '';
                final checkIn = item['CheckIN'] ?? '';
                final checkOut = item['CheckOut'] ?? '';
                final key = '$date|$checkIn|$checkOut';

                if (!seenActivities.contains(key)) {
                  parsedActivities.add(item);
                  seenActivities.add(key);
                }
              }
            }

            // Sort activities by date using AttDate field (parse dates properly)
            parsedActivities.sort((a, b) {
              final dateStrA = (a['AttDate'] ?? '').toString();
              final dateStrB = (b['AttDate'] ?? '').toString();
              final dateA = _parseAttDate(dateStrA);
              final dateB = _parseAttDate(dateStrB);
              if (dateA != null && dateB != null) {
                return dateB.compareTo(dateA); // Descending order (newest first)
              }
              // Fallback to string comparison if parsing fails
              return dateStrB.compareTo(dateStrA);
            });

            recentActivities.value = parsedActivities;

          } catch (e) {
            print('Error parsing recent activities: $e');
            recentActivities.value = [];
          }
        }

        // Parse Legends
        if (data['legends'] != null) {
          try {
            final legendsList = data['legends'] as List;
            final parsedLegends = <Map<String, dynamic>>[];

            for (final item in legendsList) {
              if (item is Map<String, dynamic>) {
                parsedLegends.add(item);
              }
            }

            legends.value = parsedLegends;
          } catch (e) {
            print('Error parsing legends: $e');
            legends.value = [];
          }
        }

        // Parse Attendance Static Contents
        if (data['StaticContents'] != null) {
          try {
            final contents = data['StaticContents'] as List;
            final tempContents = <String, String>{};

            for (final content in contents) {
              if (content is Map<String, dynamic>) {
                final contentType = content['ContentType']?.toString();
                final contentText = content['ContentText']?.toString() ?? '';

                if (contentType != null) {
                  tempContents[contentType] = contentText;
                }
              }
            }

            attendanceStaticContents.value = tempContents;
          } catch (e) {
            print('Error parsing attendance static contents: $e');
            attendanceStaticContents.value = {};
          }
        }
  }

  void refreshAttendanceData() {
    fetchAttendanceData();
  }

  Future<void> fetchProfileData({bool silent = false}) async {
    try {
      final storage = GetStorage();
      if (!silent) {
        final cachedData = storage.read('cachedProfileData');
        if (cachedData != null) {
          _parseProfileData(cachedData);
          silent = true;
        } else {
          isProfileLoading.value = true;
        }
      }
      hasProfileError.value = false;
      profileErrorMessage.value = '';

      String instanceName = storage.read('instanceName') ?? '';
      String userName = storage.read('username') ?? '';
      String userEmail = storage.read('email') ?? '';
      
      String usrEmailValue = userName.isNotEmpty ? userName : userEmail;

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getProfileData,
        queryParameters: {
          'instanceName': instanceName,
          'Usremail': usrEmailValue,
          'Lang': languageController.currentLangCode,
        },
      );

      if (response.statusCode == 200) {
        storage.write('cachedProfileData', response.data);
        _parseProfileData(response.data);
      }
    } catch (e) {
      hasProfileError.value = true;
      profileErrorMessage.value = 'Failed to load profile data: ${e.toString()}';
      print('Error fetching profile data: $e');
    } finally {
      isProfileLoading.value = false;
    }
  }

  void _parseProfileData(dynamic data) {
    if (data == null) return;
    // Parse Contact Information
        if (data['Contact information'] != null) {
          try {
            final contactInfo =
                data['Contact information'] as Map<String, dynamic>;
            profileEmpNumber.value =
                contactInfo['Emp_Number']?.toString() ?? '';
            profileEmployeeName.value =
                contactInfo['EmployeeName']?.toString() ?? '';
            profileEmpEmail.value = contactInfo['Emp_Email']?.toString() ?? '';
            profileEmpMobile.value =
                contactInfo['Emp_Mobile']?.toString() ?? '';
          } catch (e) {
            print('Error parsing contact information: $e');
            profileEmpNumber.value = '';
            profileEmployeeName.value = '';
            profileEmpEmail.value = '';
            profileEmpMobile.value = '';
          }
        }

        // Parse Work Information
        if (data['Work Information'] != null) {
          try {
            final workList = data['Work Information'] as List;
            final parsedWork = <Map<String, dynamic>>[];

            for (final item in workList) {
              if (item is Map<String, dynamic>) {
                parsedWork.add(item);
              }
            }

            workInformation.value = parsedWork;
          } catch (e) {
            print('Error parsing work information: $e');
            workInformation.value = [];
          }
        }

        // Parse Skills
        if (data['Skills'] != null) {
          try {
            final skillsList = data['Skills'] as List;
            final parsedSkills = <Map<String, dynamic>>[];

            for (final item in skillsList) {
              if (item is Map<String, dynamic>) {
                parsedSkills.add(item);
              }
            }

            skills.value = parsedSkills;
          } catch (e) {
            print('Error parsing skills: $e');
            skills.value = [];
          }
        }

        // Parse Certifications
        if (data['Certifications'] != null) {
          try {
            final certList = data['Certifications'] as List;
            final parsedCerts = <Map<String, dynamic>>[];

            for (final item in certList) {
              if (item is Map<String, dynamic>) {
                parsedCerts.add(item);
              }
            }

            certifications.value = parsedCerts;
          } catch (e) {
            print('Error parsing certifications: $e');
            certifications.value = [];
          }
        }

        // Parse Profile Static Contents
        if (data['StaticContents'] != null) {
          try {
            final contents = data['StaticContents'] as List;
            final tempContents = <String, String>{};

            for (final content in contents) {
              if (content is Map<String, dynamic>) {
                final contentType = content['ContentType']?.toString();
                final contentText = content['ContentText']?.toString() ?? '';

                if (contentType != null) {
                  tempContents[contentType] = contentText;
                }
              }
            }

            profileStaticContents.value = tempContents;
          } catch (e) {
            print('Error parsing profile static contents: $e');
            profileStaticContents.value = {};
          }
        }
  }

  void refreshProfileData() {
    fetchProfileData();
  }

  Future<void> fetchNotificationData({bool silent = false}) async {
    try {
      if (!silent) isNotificationLoading.value = true;
      hasNotificationError.value = false;
      notificationErrorMessage.value = '';

      String instanceName = await GetStorage().read('instanceName');
      String userName = await GetStorage().read('username');
      String userEmail = await GetStorage().read('email');
      
      String usrEmailValue = (userName.toString().isNotEmpty)
          ? userName.toString()
          : (userEmail ?? '').toString();

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getNotifcnData,
        queryParameters: {
          'instanceName': instanceName,
          'usrEmail': usrEmailValue,
          'lang': languageController.currentLangCode == 'ar' ? 2 : 1,
        },
        options: Options(
          responseType: ResponseType.json,
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = json.decode(data);
          } catch (e) {
            print('DEBUG: Failed to parse JSON: $e');
          }
        }

        print('Notification API Response: $data');

        // Parse Notifications
        if (data is Map && data['Notifications'] != null) {
          try {
            final notificationsList = data['Notifications'] as List;
            final parsedNotifications = <Map<String, dynamic>>[];
            for (final item in notificationsList) {
              if (item is Map) {
                parsedNotifications.add(Map<String, dynamic>.from(item));
              }
            }
            notifications.assignAll(parsedNotifications);

            // Notifications disabled for this release
            // Check for new notifications and show local push notification
            // await _notificationService.checkForNewNotifications(
            //   parsedNotifications.length,
            // );
          } catch (e) {
            print('Error parsing notifications: $e');
            notifications.value = [];
          }
        }

        // Parse Static Contents
        if (data is Map && data['StaticContents'] != null) {
          try {
            final contents = data['StaticContents'] as List;
            final tempContents = <String, String>{};

            for (final item in contents) {
              if (item is Map) {
                final content = Map<String, dynamic>.from(item);
                final contentType = content['ContentType']?.toString();
                final contentText = content['ContentText']?.toString() ?? '';

                if (contentType != null) {
                  tempContents[contentType] = contentText;
                }
              }
            }

            notificationStaticContents.assignAll(tempContents);
          } catch (e) {
            print('Error parsing notification static contents: $e');
            notificationStaticContents.value = {};
          }
        }

        // Parse Common Contents
        if (data is Map && data['CommonContents'] != null) {
          try {
            final commonList = data['CommonContents'] as List;
            final tempCommon = <String, String>{};

            for (final item in commonList) {
              if (item is Map) {
                final content = Map<String, dynamic>.from(item);
                final baseUrl = content['BaseUrl']?.toString() ?? '';
                tempCommon['BaseUrl'] = baseUrl;
              }
            }

            commonContents.assignAll(tempCommon);
          } catch (e) {
            print('Error parsing common contents: $e');
            commonContents.value = {};
          }
        }
      }
    } catch (e) {
      hasNotificationError.value = true;
      notificationErrorMessage.value =
          'Failed to load notification data: ${e.toString()}';
      print('Error fetching notification data: $e');
    } finally {
      isNotificationLoading.value = false;
    }
  }

  Future<void> updateNotificationReadStatus(
    int notificationId,
    int readStatus, {
    bool refreshAfterUpdate = true,
  }) async {
    try {
      String instanceName = await GetStorage().read('instanceName');
      String userName = await GetStorage().read('username');
      String userEmail = await GetStorage().read('email');
      
      String usrEmailValue = (userName.toString().isNotEmpty)
          ? userName.toString()
          : (userEmail ?? '').toString();

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.updateReadStatus,
        queryParameters: {
          'instanceName': instanceName,
          'Usremail': usrEmailValue,
          'Lang': languageController.currentLangCode,
          'notifcnID': notificationId,
          'readStatus': readStatus,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        print('Update Read Status Response: $data');

        // Refresh notification data after update only if requested
        if (refreshAfterUpdate) {
        await fetchNotificationData();
        }

        return;
      }
    } catch (e) {
      print('Error updating notification read status: $e');
      rethrow;
    }
  }

  void refreshNotificationData() {
    fetchNotificationData();
  }

  // Show individual notification for specific events
  Future<void> showIndividualNotification(String title, String body) async {
    await _notificationService.showCustomNotification(
      title: title,
      body: body,
      payload: 'custom_notification',
    );
  }

  // Fetch support URL from API
  Future<String?> getSupportURL() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getSupportURL,
      );

      if (response.statusCode == 200 &&
          response.data is List &&
          response.data.isNotEmpty) {
        final data = response.data[0];
        return data['SupportURL'] as String?;
      }
    } catch (e) {
      print('Error fetching support URL: $e');
    }
    return null;
  }

  // Notification Polling Methods
  void _loadPollingSettings() {
    final storage = GetStorage();
    isPollingEnabled.value = storage.read('notificationPollingEnabled') ?? true;
    pollingIntervalMinutes.value =
        storage.read('notificationPollingInterval') ?? 2;
    pushNotificationsEnabled.value = storage.read('pushNotificationsEnabled') ?? true;
  }

  void _savePollingSettings() {
    final storage = GetStorage();
    storage.write('notificationPollingEnabled', isPollingEnabled.value);
    storage.write('notificationPollingInterval', pollingIntervalMinutes.value);
    storage.write('pushNotificationsEnabled', pushNotificationsEnabled.value);
  }

  void _startNotificationPolling() {
    // Disabled for V2
  }

  void _stopNotificationPolling() {
    // Disabled for V2
  }

  Future<void> _pollForNotifications() async {
    // Disabled for V2
  }

  Future<void> _fetchNotificationDataSilently() async {
    try {
      String instanceName = await GetStorage().read('instanceName');
      String userName = await GetStorage().read('username');
      String userEmail = await GetStorage().read('email');
      
      String usrEmailValue = (userName.toString().isNotEmpty)
          ? userName.toString()
          : (userEmail ?? '').toString();

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getNotifcnData,
        queryParameters: {
          'instanceName': instanceName,
          'usrEmail': usrEmailValue,
          'lang': languageController.currentLangCode,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Parse Notifications
        if (data['Notifications'] != null) {
          try {
            final notificationsList = data['Notifications'] as List;
            final parsedNotifications = <Map<String, dynamic>>[];

            for (final item in notificationsList) {
              if (item is Map<String, dynamic>) {
                parsedNotifications.add(item);
              }
            }

            notifications.value = parsedNotifications;
          } catch (e) {
            print('Error parsing notifications during polling: $e');
          }
        }

        // Parse Static Contents
        if (data['StaticContents'] != null) {
          try {
            final staticContentsList = data['StaticContents'] as List;
            final parsedStaticContents = <String, String>{};

            for (final item in staticContentsList) {
              if (item is Map<String, dynamic>) {
                final contentType = item['ContentType'] as String?;
                final contentText = item['ContentText'] as String?;
                if (contentType != null && contentText != null) {
                  parsedStaticContents[contentType] = contentText;
                }
              }
            }

            notificationStaticContents.value = parsedStaticContents;
          } catch (e) {
            print('Error parsing static contents during polling: $e');
          }
        }

        // Parse Common Contents
        if (data['CommonContents'] != null) {
          try {
            final commonContentsList = data['CommonContents'] as List;
            final parsedCommonContents = <String, String>{};

            for (final item in commonContentsList) {
              if (item is Map<String, dynamic>) {
                item.forEach((key, value) {
                  if (value is String) {
                    parsedCommonContents[key] = value;
                  }
                });
              }
            }

            commonContents.value = parsedCommonContents;
          } catch (e) {
            print('Error parsing common contents during polling: $e');
          }
        }
      }
    } catch (e) {
      print('Error fetching notification data silently: $e');
    }
  }

  // Public methods to control polling
  void enableNotificationPolling() {
    isPollingEnabled.value = true;
    _savePollingSettings();
    _startNotificationPolling();
  }

  void disableNotificationPolling() {
    isPollingEnabled.value = false;
    _savePollingSettings();
    _stopNotificationPolling();
  }

  void enablePushNotifications() {
    pushNotificationsEnabled.value = true;
    _savePollingSettings();
  }

  void disablePushNotifications() {
    pushNotificationsEnabled.value = false;
    _savePollingSettings();
  }

  void updatePollingInterval(int minutes) {
    pollingIntervalMinutes.value = minutes;
    _savePollingSettings();

    // Restart polling with new interval
    if (isPollingEnabled.value) {
      _stopNotificationPolling();
      _startNotificationPolling();
    }
  }

  void forceNotificationCheck() {
    _pollForNotifications();
  }

  Future<void> fetchSettingsData({bool silent = false}) async {
    try {
      final storage = GetStorage();
      if (!silent) {
        final cachedData = storage.read('cachedSettingsData');
        if (cachedData != null) {
          _parseSettingsData(cachedData);
          silent = true;
        } else {
          isSettingsLoading.value = true;
        }
      }
      hasSettingsError.value = false;
      settingsErrorMessage.value = '';

      String instanceName = storage.read('instanceName') ?? '';
      String userEmail = storage.read('email') ?? '';

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getSettingsData,
        queryParameters: {
          'instanceName': instanceName,
          'usrEmail': userEmail,
          'lang': languageController.currentLangCode,
        },
      );

      if (response.statusCode == 200) {
        storage.write('cachedSettingsData', response.data);
        _parseSettingsData(response.data);
      }
    } catch (e) {
      hasSettingsError.value = true;
      settingsErrorMessage.value = 'Failed to load settings data: ${e.toString()}';
      print('Error fetching settings data: $e');
    } finally {
      isSettingsLoading.value = false;
    }
  }

  void _parseSettingsData(dynamic data) {
    if (data == null) return;
    // Parse Settings Static Contents
        if (data['StaticContents'] != null) {
          try {
            final contents = data['StaticContents'] as List;
            final tempContents = <String, String>{};

            for (final content in contents) {
              if (content is Map<String, dynamic>) {
                final contentType = content['ContentType']?.toString();
                final contentText = content['ContentText']?.toString() ?? '';

                if (contentType != null) {
                  tempContents[contentType] = contentText;
                }
              }
            }

            settingsStaticContents.value = tempContents;
          } catch (e) {
            print('Error parsing settings static contents: $e');
            settingsStaticContents.value = {};
          }
        }
  }

  void refreshSettingsData() {
    fetchSettingsData();
  }

  // Refresh all data after language change
  void refreshAllData() {
    // Clear the cached HR portal URL so it gets re-fetched on demand with the new language code
    cachedPortalUrl.value = '';

    fetchHomeData();
    fetchSettingsData();
    // fetchNotificationData(); // Disabled for V2
    fetchAttendanceData();
    fetchProfileData(); // Ensure profile tab static contents update with language
    // Refresh profile picture URL with new language
    initializeProfilePicture();
  }

  // Get Profile Picture URL
  String getProfilePictureUrl() {
    final instanceName = GetStorage().read('instanceName') ?? '';
    final userEmail = GetStorage().read('email') ?? '';
    final languageController = Get.find<LanguageController>();

    if (instanceName.isNotEmpty && userEmail.isNotEmpty) {
      return '${ApiEndpoints.getProfPicture}?instanceName=$instanceName&usrEmail=$userEmail&lang=${languageController.currentLangCode}';
    }
    return '';
  }

  // Initialize profile picture URL
  void initializeProfilePicture() {
    profilePictureUrl.value = getProfilePictureUrl();
  }

  // Pre-fetch portal URL for faster loading
  Future<void> preFetchPortalUrl() async {
    try {
      String instanceName = GetStorage().read('instanceName')?.toString() ?? '';
      String userName = GetStorage().read('username')?.toString() ?? '';
      String userEmail = GetStorage().read('email')?.toString() ?? '';
      
      // FIX: Prioritize username over email because the backend now rejects full emails!
      String usrEmailValue = userName.isNotEmpty ? userName : userEmail;
      if (usrEmailValue.isEmpty || instanceName.isEmpty) return;

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getPortalUrl,
        queryParameters: {
          'usrEmail': usrEmailValue,
          'instanceName': instanceName,
          'lang': languageController.currentLangCode,
        },
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      if (response.statusCode == 200 && response.data != null) {
        final url = _extractPortalUrl(response.data);
        if (url != null && url.isNotEmpty) {
          cachedPortalUrl.value = url;
        }
      }
    } catch (e) {
      // API might be broken or offline, fail silently
      print('Pre-fetch portal URL failed: $e');
    }
  }

  /// Extracts ClientUrl from potentially wrapped response data.
  String? _extractPortalUrl(dynamic responseData) {
    var data = responseData;

    // Parse if string
    if (data is String) {
      try {
        String cleanData = data.replaceAll('\uFEFF', '').trim();
        if (cleanData.startsWith('"') && cleanData.endsWith('"')) {
          cleanData = cleanData.substring(1, cleanData.length - 1).replaceAll('\\"', '"');
        }
        data = jsonDecode(cleanData);
      } catch (e) {
        return null;
      }
    }

    if (data is List && data.isNotEmpty) {
      final rawUrl = data[0]['ClientUrl']?.toString();
      return rawUrl != null ? _fixPortalUrlCasing(rawUrl) : null;
    }
    return null;
  }

  /// Fixes case-sensitivity issues in the portal URL path.
  /// The API returns 'nspApp' (lowercase) but the server expects 'NSPApp' (uppercase).
  String _fixPortalUrlCasing(String url) {
    return url
        .replaceAll('/nspApp/', '/NSPApp/')
        .replaceAll('/nspapp/', '/NSPApp/');
  }

  // Helper to append language to the portal URL
  String appendLangToUrl(String url) {
    try {
      final langCode = Get.find<LanguageController>().currentLangCode.toString();
      final uri = Uri.parse(url);
      final newParams = Map<String, dynamic>.from(uri.queryParameters);
      newParams['lang'] = langCode;
      return uri.replace(queryParameters: newParams).toString();
    } catch (e) {
      final separator = url.contains('?') ? '&' : '?';
      return '$url${separator}lang=${Get.find<LanguageController>().currentLangCode}';
    }
  }

  // Launch HR Portal
  Future<void> launchHrPortal({String? title}) async {
    try {
      if (cachedPortalUrl.value.isNotEmpty) {
        final headText = title ?? staticContents['HrLinkHeadText'] ?? 'hr_portal'.tr;
        Get.toNamed(AppRoutes.webview,
            preventDuplicates: true,
            parameters: {'url': appendLangToUrl(cachedPortalUrl.value), 'title': headText});
        return;
      }

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      String instanceName = GetStorage().read('instanceName')?.toString() ?? '';
      String userName = GetStorage().read('username')?.toString() ?? '';
      String userEmail = GetStorage().read('email')?.toString() ?? '';
      
      // FIX: Prioritize username over email
      String usrEmailValue = userName.isNotEmpty ? userName : userEmail;

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getPortalUrl,
        queryParameters: {
          'usrEmail': usrEmailValue,
          'instanceName': instanceName,
          'lang': languageController.currentLangCode,
        },
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      if (Get.isDialogOpen == true) {
        Navigator.of(Get.overlayContext!).pop();
      }

      if (response.statusCode == 200 && response.data != null) {
        final clientUrl = _extractPortalUrl(response.data);

        if (clientUrl != null && clientUrl.isNotEmpty) {
          // Cache for next time
          cachedPortalUrl.value = clientUrl;
          final headText = title ?? staticContents['HrLinkHeadText'] ?? 'hr_portal'.tr;
          Get.toNamed(AppRoutes.webview,
              preventDuplicates: true,
              parameters: {'url': appendLangToUrl(clientUrl), 'title': headText});
          return; // Success, exit method
        }
      }

      Get.defaultDialog(
        title: 'API Error',
        middleText: 'Status: ${response.statusCode}\nData: ${response.data}\nParams: $usrEmailValue / $instanceName',
        textConfirm: 'OK',
        confirmTextColor: Colors.white,
        onConfirm: () {
          if (Get.isDialogOpen == true) Navigator.of(Get.overlayContext!).pop();
        },
      );
    } catch (e) {
      if (Get.isDialogOpen == true) {
        Navigator.of(Get.overlayContext!).pop();
      }
      print('Error launching HR portal: $e');
      Get.defaultDialog(
        title: 'Error',
        middleText: 'hr_portal_error'.tr,
        textConfirm: 'OK',
        confirmTextColor: Colors.white,
        onConfirm: () {
          if (Get.isDialogOpen == true) Navigator.of(Get.overlayContext!).pop();
        },
      );
    }
  }

  /// Parses AttDate strings in multiple formats for proper date sorting.
  /// API returns dates like "23/03/2025" (dd/MM/yyyy) or "03/23/2025" (MM/dd/yyyy).
  DateTime? _parseAttDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    final trimmed = dateStr.trim();
    
    // Try dd/MM/yyyy first (most common from API)
    try {
      final parts = trimmed.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        // If day > 12, it's definitely dd/MM/yyyy
        if (day > 12) {
          return DateTime(year, month, day);
        }
        // If month > 12, it's MM/dd/yyyy
        if (month > 12) {
          return DateTime(year, day, month);
        }
        // Ambiguous case (both <= 12): assume dd/MM/yyyy since that's the API pattern
        return DateTime(year, month, day);
      }
    } catch (_) {}

    // Try yyyy-MM-dd (ISO format)
    try {
      return DateTime.parse(trimmed);
    } catch (_) {}

    return null;
  }
}
