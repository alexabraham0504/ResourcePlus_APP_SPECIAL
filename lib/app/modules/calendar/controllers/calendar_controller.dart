// CalendarController — DISABLED for production build.
// Google Calendar integration is not included in the production release.

import 'package:get/get.dart';

class CalendarController extends GetxController {
  // Stub — calendar module is disabled for production
  final RxBool isAuthenticated = false.obs;
  final RxBool isLoading = false.obs;
  final RxList events = [].obs;
  final RxList todayEvents = [].obs;
  final RxList calendars = [].obs;
  final RxString selectedCalendarId = 'primary'.obs;
}
