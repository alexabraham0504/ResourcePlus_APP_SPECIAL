import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';
import '../../../controllers/language_controller.dart';
import '../../../services/notification_service.dart';
import '../../../services/api_service.dart';
import '../../../config/api_endpoints.dart';
import '../../../routes/app_routes.dart';

class HomeController extends GetxController {
  final Dio _dio = ApiService().dio;
  final NotificationService _notificationService = NotificationService();

  // Scaffold key for drawer control
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

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
    return notifications.where((notification) {
      final readStatusValue =
          notification['ReadStatus'] ??
          notification['IsRead'] ??
          notification['isRead'];
      final isRead =
          readStatusValue == 'True' ||
          readStatusValue == 'true' ||
          readStatusValue == 1 ||
          readStatusValue == true;
      return !isRead;
    }).length;
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

  @override
  void onInit() {
    super.onInit();
    // Start all core data fetches concurrently in the background
    // This dramatically reduces perceived load time when navigating tabs
    fetchHomeData();
    fetchAttendanceData();
    fetchProfileData();
    fetchNotificationData();
    fetchSettingsData();
    
    initializeProfilePicture();
    _loadPollingSettings();
    _startNotificationPolling();
  }

  @override
  void onClose() {
    _stopNotificationPolling();
    super.onClose();
  }

  void changeTab(int index) {
    currentIndex.value = index;
    // Only fetch if data hasn't been loaded yet to prevent redundant loading spinners
    if (index == 1 && attendanceRate.isEmpty) {
      fetchAttendanceData();
    }
    if (index == 2 && profileEmpNumber.value.isEmpty) {
      fetchProfileData();
    }
    if (index == 3 && notifications.isEmpty) {
      fetchNotificationData();
    }
    if (index == 4 && settingsStaticContents.isEmpty) {
      fetchSettingsData();
    }
  }

  Future<void> fetchHomeData() async {
    try {
      isLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';

      // TODO: Get these values from auth controller or shared preferences
      String instanceName = await GetStorage().read(
        'instanceName',
      ); //'Universal';
      String userName = await GetStorage().read('username');
      String userEmail = await GetStorage().read(
        'email',
      ); // 'email@netsoftpro.net';
      
      String usrEmailValue = (userName != null && userName.toString().isNotEmpty)
          ? userName.toString()
          : (userEmail ?? '').toString();

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
        final data = response.data;
        print('API Response: $data'); // Debug print

        // Parse employee details
        if (data['EmployeeDetails'] != null) {
          try {
            final empDetails = data['EmployeeDetails'];
            print('EmployeeDetails type: ${empDetails.runtimeType}');
            print('EmployeeDetails value: $empDetails');

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
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Failed to load home data: ${e.toString()}';
      print('Error fetching home data: $e');
      print('Error stack trace: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  void refreshData() {
    fetchHomeData();
  }

  Future<void> fetchAttendanceData() async {
    try {
      isAttendanceLoading.value = true;
      hasAttendanceError.value = false;
      attendanceErrorMessage.value = '';

      String instanceName = await GetStorage().read('instanceName');
      String userName = await GetStorage().read('username');
      String userEmail = await GetStorage().read('email');
      
      String usrEmailValue = (userName != null && userName.toString().isNotEmpty)
          ? userName.toString()
          : (userEmail ?? '').toString();

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getAttData,
        queryParameters: {
          'instanceName': instanceName,
          'Usremail': usrEmailValue,
          'Lang': languageController.currentLangCode,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        print('Attendance API Response: $data');

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
    } catch (e) {
      hasAttendanceError.value = true;
      attendanceErrorMessage.value =
          'Failed to load attendance data: ${e.toString()}';
      print('Error fetching attendance data: $e');
    } finally {
      isAttendanceLoading.value = false;
    }
  }

  void refreshAttendanceData() {
    fetchAttendanceData();
  }

  Future<void> fetchProfileData() async {
    try {
      isProfileLoading.value = true;
      hasProfileError.value = false;
      profileErrorMessage.value = '';

      String instanceName = await GetStorage().read('instanceName');
      String userName = await GetStorage().read('username');
      String userEmail = await GetStorage().read('email');
      
      String usrEmailValue = (userName != null && userName.toString().isNotEmpty)
          ? userName.toString()
          : (userEmail ?? '').toString();

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
        final data = response.data;
        print('Profile API Response: $data');

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
    } catch (e) {
      hasProfileError.value = true;
      profileErrorMessage.value =
          'Failed to load profile data: ${e.toString()}';
      print('Error fetching profile data: $e');
    } finally {
      isProfileLoading.value = false;
    }
  }

  void refreshProfileData() {
    fetchProfileData();
  }

  Future<void> fetchNotificationData() async {
    try {
      isNotificationLoading.value = true;
      hasNotificationError.value = false;
      notificationErrorMessage.value = '';

      String instanceName = await GetStorage().read('instanceName');
      String userName = await GetStorage().read('username');
      String userEmail = await GetStorage().read('email');
      
      String usrEmailValue = (userName != null && userName.toString().isNotEmpty)
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
        print('Notification API Response: $data');

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

            // Check for new notifications and show local push notification
            await _notificationService.checkForNewNotifications(
              parsedNotifications.length,
            );
          } catch (e) {
            print('Error parsing notifications: $e');
            notifications.value = [];
          }
        }

        // Parse Static Contents
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

            notificationStaticContents.value = tempContents;
          } catch (e) {
            print('Error parsing notification static contents: $e');
            notificationStaticContents.value = {};
          }
        }

        // Parse Common Contents
        if (data['CommonContents'] != null) {
          try {
            final commonList = data['CommonContents'] as List;
            final tempCommon = <String, String>{};

            for (final content in commonList) {
              if (content is Map<String, dynamic>) {
                final baseUrl = content['BaseUrl']?.toString() ?? '';
                tempCommon['BaseUrl'] = baseUrl;
              }
            }

            commonContents.value = tempCommon;
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
      
      String usrEmailValue = (userName != null && userName.toString().isNotEmpty)
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
    if (!isPollingEnabled.value || isPollingActive.value) return;

    if (kDebugMode) {
      print(
        'Starting notification polling every ${pollingIntervalMinutes.value} minutes',
      );
    }
    isPollingActive.value = true;

    _notificationTimer = Timer.periodic(
      Duration(minutes: pollingIntervalMinutes.value),
      (timer) => _pollForNotifications(),
    );
  }

  void _stopNotificationPolling() {
    if (kDebugMode) {
      print('Stopping notification polling');
    }
    _notificationTimer?.cancel();
    _notificationTimer = null;
    isPollingActive.value = false;
  }

  Future<void> _pollForNotifications() async {
    if (!isPollingEnabled.value) return;

    try {
      if (kDebugMode) {
        print('Polling for new notifications...');
      }
      final previousCount = notifications.length;

      // Fetch notifications silently (without showing loading)
      await _fetchNotificationDataSilently();

      final newCount = notifications.length;

      if (newCount > previousCount) {
        if (kDebugMode) {
          print('New notifications detected! Count: $previousCount -> $newCount');
        }
        // Show local notification for new notifications only if push notifications are enabled
        if (pushNotificationsEnabled.value) {
          await _notificationService.checkForNewNotifications(newCount);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during notification polling: $e');
      }
    }
  }

  Future<void> _fetchNotificationDataSilently() async {
    try {
      String instanceName = await GetStorage().read('instanceName');
      String userName = await GetStorage().read('username');
      String userEmail = await GetStorage().read('email');
      
      String usrEmailValue = (userName != null && userName.toString().isNotEmpty)
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

  Future<void> fetchSettingsData() async {
    try {
      isSettingsLoading.value = true;
      hasSettingsError.value = false;
      settingsErrorMessage.value = '';

      String instanceName = await GetStorage().read('instanceName');
      String userEmail = await GetStorage().read('email');

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
        final data = response.data;
        print('Settings API Response: $data');

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
    } catch (e) {
      hasSettingsError.value = true;
      settingsErrorMessage.value =
          'Failed to load settings data: ${e.toString()}';
      print('Error fetching settings data: $e');
    } finally {
      isSettingsLoading.value = false;
    }
  }

  void refreshSettingsData() {
    fetchSettingsData();
  }

  // Refresh all data after language change
  void refreshAllData() {
    fetchHomeData();
    fetchSettingsData();
    fetchNotificationData();
    fetchAttendanceData();
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

  Future<void> launchHrPortal({String? title}) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      String instanceName = GetStorage().read('instanceName')?.toString() ?? '';
      String userName = GetStorage().read('username')?.toString() ?? '';
      String userEmail = GetStorage().read('email')?.toString() ?? '';
      
      String usrEmailValue = userEmail.isNotEmpty
          ? userEmail
          : userName;

      final languageController = Get.find<LanguageController>();

      final response = await _dio.get(
        ApiEndpoints.getPortalUrl,
        queryParameters: {
          'usrEmail': usrEmailValue,
          'instanceName': instanceName,
          'lang': languageController.currentLangCode,
        },
      );

      if (Get.isDialogOpen == true) {
        Navigator.of(Get.overlayContext!).pop();
      }

      if (response.statusCode == 200 && response.data != null) {
        var responseData = response.data;
        if (responseData is String) {
          try {
            String cleanData = responseData.replaceAll('\uFEFF', '').trim();
            if (cleanData.startsWith('"') && cleanData.endsWith('"')) {
              cleanData = cleanData.substring(1, cleanData.length - 1).replaceAll('\\"', '"');
            }
            responseData = jsonDecode(cleanData);
          } catch (e) {
            print('JSON decode error for GetPortalUrl: $e');
          }
        }

        List<dynamic>? dataList;
        if (responseData is List) {
          dataList = responseData;
        }

        if (dataList != null && dataList.isNotEmpty) {
          final clientUrl = dataList[0]['ClientUrl']?.toString() ?? '';
          if (clientUrl.isNotEmpty) {
            final headText = title ?? staticContents['HrLinkHeadText'] ?? 'hr_portal'.tr;
            Get.toNamed(AppRoutes.webview,
                preventDuplicates: true,
                parameters: {'url': clientUrl, 'title': headText});
            return;
          }
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
