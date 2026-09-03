import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/appointment.dart';
import '../models/reminder_settings.dart';

/// שירות אחסון מקומי - שומר את כל התורים במכשיר עצמו (עובד גם ללא אינטרנט)
class StorageService {
  static const _appointmentsKey = 'appointments_v2';
  static const _settingsKey = 'sync_settings_v1';
  static const _wifiKey = 'wifi_settings_v1';
  static const _reminderKey = 'reminder_settings_v1';

  Future<List<Appointment>> loadAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appointmentsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAppointments(List<Appointment> appointments) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(appointments.map((a) => a.toJson()).toList());
    await prefs.setString(_appointmentsKey, raw);
  }

  /// שמירת הגדרות סנכרון GitHub (טוקן, בעלים, ריפו, נתיב)
  Future<void> saveSyncSettings({
    required String token,
    required String owner,
    required String repo,
    required String path,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _settingsKey,
      jsonEncode({
        'token': token,
        'owner': owner,
        'repo': repo,
        'path': path,
      }),
    );
  }

  Future<Map<String, String>> loadSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  /// שמירת פרטי רשת ה-Wi-Fi של הסטודיו במכשיר, כדי שלא יהיה צורך
  /// להזין אותם מחדש בכל פעם. הפרטים נשמרים מקומית בלבד (כמו טוקן ה-GitHub)
  /// ואינם נשלחים לשום שרת חוץ מתהליך החיבור לרשת עצמו.
  Future<void> saveWifiCredentials({
    required String ssid,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _wifiKey,
      jsonEncode({'ssid': ssid, 'password': password}),
    );
  }

  Future<Map<String, String>> loadWifiCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_wifiKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  Future<void> clearWifiCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wifiKey);
  }

  /// שמירת הגדרות התזכורת (האם פעילה, כמה ימים לפני התור, ובאיזו שעה)
  Future<void> saveReminderSettings(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderKey, jsonEncode(settings.toJson()));
  }

  Future<ReminderSettings> loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reminderKey);
    if (raw == null || raw.isEmpty) return ReminderSettings.defaults();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ReminderSettings.fromJson(map);
    } catch (_) {
      return ReminderSettings.defaults();
    }
  }
}
