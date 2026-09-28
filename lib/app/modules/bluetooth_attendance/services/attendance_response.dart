import 'dart:convert';

/// Only explicit success acknowledgements may change local attendance state.
bool attendanceAccepted(int statusCode, String body) {
  if (statusCode != 200) return false;
  dynamic value;
  try {
    value = jsonDecode(body);
  } catch (_) {
    value = body.trim();
  }
  if (value is bool) return value;
  if (value is! String) return false;
  final text = value.trim().toLowerCase();
  return text == 'true' || text == 'success' || text.startsWith('true|');
}
