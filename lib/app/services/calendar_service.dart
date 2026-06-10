// CalendarService — DISABLED for production build.
// Google Calendar integration is not included in the production release.
// This stub prevents compilation errors from removed googleapis/google_sign_in dependencies.

class CalendarService {
  bool get isAuthenticated => false;

  Future<void> initialize() async {}
  Future<bool> authenticate() async => false;
  Future<void> logout() async {}
  Future<List<dynamic>> getCalendars() async => [];
  Future<List<dynamic>> getEvents({
    required String calendarId,
    DateTime? startDate,
    DateTime? endDate,
    int maxResults = 50,
  }) async => [];
  Future<dynamic> createEvent({
    required String calendarId,
    required String summary,
    required DateTime start,
    required DateTime end,
    String? description,
    String? location,
  }) async => null;
  Future<dynamic> updateEvent({
    required String calendarId,
    required String eventId,
    String? summary,
    DateTime? start,
    DateTime? end,
    String? description,
    String? location,
  }) async => null;
  Future<bool> deleteEvent({
    required String calendarId,
    required String eventId,
  }) async => false;
  Future<List<dynamic>> getTodayEvents(String calendarId) async => [];
  Future<List<dynamic>> getEventsForDateRange({
    required String calendarId,
    required DateTime startDate,
    required DateTime endDate,
  }) async => [];
}
