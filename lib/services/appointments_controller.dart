import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/appointment.dart';
import '../models/reminder_settings.dart';
import 'github_sync_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// כמה זמן משאירים "מצבות" (רשומות מחוקות) לפני שמנקים אותן לצמיתות.
/// חייב להיות ארוך מספיק כדי שלכל המכשירים תהיה הזדמנות לסנכרן ולראות
/// את המחיקה (כלומר: כדי שהיא לא "תחזור לחיים" בטעות).
const _tombstoneRetention = Duration(days: 90);

/// מצב הסנכרון מול קובץ ה-JSON ב-GitHub, לצורך הצגה בממשק.
enum SyncStatus {
  /// לא הוגדרו פרטי סנכרון (עדיין לא הוזנו טוקן/ריפו בהגדרות)
  notConfigured,

  /// מוגדר, אין פעולה פעילה כרגע
  idle,

  /// העלאה/הורדה מתבצעת כרגע ברקע
  syncing,

  /// הפעולה האחרונה הצליחה
  success,

  /// הפעולה האחרונה נכשלה (למשל אין אינטרנט)
  error,
}

/// המוח של האפליקציה: מחזיק את רשימת התורים בזיכרון, שומר לאחסון המקומי
/// בכל שינוי, ומודיע למסכים לרענן את עצמם.
///
/// הסנכרון מול GitHub הוא **דו-כיווני ומבוסס-מיזוג**, לא גיבוי חד-כיווני:
/// לכל תור יש שדה updatedAt, וכל פעולת סנכרון (העלאה אוטומטית אחרי
/// עריכה, או לחיצה על רענון) קודם מורידה את הגרסה המרוחקת, ממזגת אותה
/// עם המקומית לפי "מי עודכן אחרון מנצח" ברמת כל תור בנפרד, ורק אז
/// מעלה את התוצאה הממוזגת. כך שינוי שנעשה במכשיר אחד לא נדרס בטעות
/// על ידי גרסה ישנה יותר שמגיעה ממכשיר אחר, ומחיקות מסונכרנות אף הן
/// (באמצעות "מצבות" - ראו Appointment.deletedAt) במקום לחזור לחיים.
///
/// לגבי הפורמט: השארנו JSON (ולא מעבר ל-SQL/SQLite) כי ה-API של GitHub
/// (Contents API) בכל מקרה מעביר תמיד את *כל* הקובץ בכל שמירה - אין לו
/// דרך לעדכן רק שורה אחת בתוך קובץ קיים, גם אם היה מדובר בקובץ SQLite.
/// כלומר המעבר לא היה פותר את "כל הקובץ מוחלף" ברמת התעבורה. מה שכן
/// באמת פתר את זה הוא הוספת updatedAt/deletedAt לכל רשומה, כך שברמה
/// הלוגית רק מה שבאמת השתנה "מנצח" במיזוג - וזה עובד מצוין מעל JSON.
class AppointmentsController extends ChangeNotifier {
  final StorageService _storage = StorageService();
  List<Appointment> _appointments = [];
  bool _isLoading = true;

  GitHubSyncService? _syncService;
  SyncStatus _syncStatus = SyncStatus.notConfigured;
  String? _syncError;
  DateTime? _lastSyncedAt;

  ReminderSettings _reminderSettings = ReminderSettings.defaults();
  ReminderSettings get reminderSettings => _reminderSettings;

  /// כל התורים החיים (לא כולל מצבות מחיקה) - זה מה שהמסכים אמורים
  /// להשתמש בו כמעט תמיד.
  List<Appointment> get appointments =>
      List.unmodifiable(_appointments.where((a) => !a.isDeleted));
  bool get isLoading => _isLoading;

  SyncStatus get syncStatus => _syncStatus;
  String? get syncError => _syncError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isSyncConfigured => _syncService != null;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _appointments = await _storage.loadAppointments();
    _appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    await _loadSyncSettings();
    _reminderSettings = await _storage.loadReminderSettings();
    NotificationService.instance.configure(_reminderSettings);
    unawaited(NotificationService.instance.rescheduleAll(appointments));
    _isLoading = false;
    notifyListeners();
  }

  /// נקרא ממסך הגדרות התזכורות לאחר שינוי (הפעלה/כיבוי, כמות ימים, שעה) -
  /// שומר את ההגדרה החדשה, ומתזמן מחדש את כל התזכורות הקיימות כדי
  /// שהשינוי ייכנס לתוקף מיד בלי צורך להפעיל מחדש את האפליקציה.
  Future<void> applyReminderSettings(ReminderSettings settings) async {
    _reminderSettings = settings;
    await _storage.saveReminderSettings(settings);
    NotificationService.instance.configure(settings);
    await NotificationService.instance.rescheduleAll(appointments);
    notifyListeners();
  }

  Future<void> _loadSyncSettings() async {
    final settings = await _storage.loadSyncSettings();
    _buildSyncService(settings);
  }

  void _buildSyncService(Map<String, String> settings) {
    final token = settings['token'] ?? '';
    final owner = settings['owner'] ?? '';
    final repo = settings['repo'] ?? '';
    final path = settings['path'] ?? '';
    if (token.isEmpty || owner.isEmpty || repo.isEmpty || path.isEmpty) {
      _syncService = null;
      _syncStatus = SyncStatus.notConfigured;
    } else {
      _syncService = GitHubSyncService(
        token: token,
        owner: owner,
        repo: repo,
        path: path,
      );
      _syncStatus = SyncStatus.idle;
    }
    _syncError = null;
  }

  /// נקרא ממסך ההגדרות מיד לאחר שמירת פרטי הסנכרון, כדי שהסנכרון
  /// האוטומטי יתחיל לפעול בלי צורך להפעיל מחדש את האפליקציה.
  void applySyncSettings({
    required String token,
    required String owner,
    required String repo,
    required String path,
  }) {
    _buildSyncService({
      'token': token,
      'owner': owner,
      'repo': repo,
      'path': path,
    });
    notifyListeners();
  }

  List<Appointment> forDay(DateTime day) {
    return _appointments
        .where((a) =>
            !a.isDeleted &&
            a.dateTime.year == day.year &&
            a.dateTime.month == day.month &&
            a.dateTime.day == day.day)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  /// מפת ימים עם תורים - משמש להצגת נקודות על הלוח שנה
  Set<DateTime> get daysWithAppointments => _appointments
      .where((a) => !a.isDeleted)
      .map((a) => DateTime(a.dateTime.year, a.dateTime.month, a.dateTime.day))
      .toSet();

  double totalForMonth(DateTime month) {
    return _appointments
        .where((a) =>
            !a.isDeleted &&
            a.dateTime.year == month.year &&
            a.dateTime.month == month.month &&
            a.status != AppointmentStatus.cancelled)
        .fold(0.0, (sum, a) => sum + a.price);
  }

  int countForMonth(DateTime month) {
    return _appointments
        .where((a) =>
            !a.isDeleted &&
            a.dateTime.year == month.year &&
            a.dateTime.month == month.month)
        .length;
  }

  Future<void> add(Appointment appointment) async {
    final stamped = appointment.copyWith(updatedAt: DateTime.now());
    _appointments.add(stamped);
    _appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    notifyListeners();
    await _storage.saveAppointments(_appointments);
    unawaited(NotificationService.instance.scheduleReminder(stamped));
    unawaited(_syncUpload());
  }

  Future<void> update(Appointment appointment) async {
    final index = _appointments.indexWhere((a) => a.id == appointment.id);
    if (index == -1) return;
    final stamped = appointment.copyWith(updatedAt: DateTime.now());
    _appointments[index] = stamped;
    _appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    notifyListeners();
    await _storage.saveAppointments(_appointments);
    // מבטלים ומתזמנים מחדש (למשל אם התאריך/שעה השתנו)
    unawaited(NotificationService.instance.cancelReminder(stamped.id));
    unawaited(NotificationService.instance.scheduleReminder(stamped));
    unawaited(_syncUpload());
  }

  /// "מוחקים" תור - בפועל רק מסמנים אותו כמחוק (מצבה) כדי שהמחיקה
  /// תסונכרן למכשירים אחרים במקום שהתור "יחזור לחיים" בסבב הבא.
  Future<void> delete(String id) async {
    final index = _appointments.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final now = DateTime.now();
    _appointments[index] =
        _appointments[index].copyWith(deletedAt: now, updatedAt: now);
    notifyListeners();
    await _storage.saveAppointments(_appointments);
    unawaited(NotificationService.instance.cancelReminder(id));
    unawaited(_syncUpload());
  }

  /// ממזג רשימת תורים מקומית עם רשימה שהתקבלה מרחוק, ברמת כל תור
  /// בנפרד: מי שעודכן לאחרונה (updatedAt) הוא זה שמנצח. כך אם תור
  /// נערך במכשיר A ותור *אחר* נוסף במכשיר B, שני השינויים נשמרים -
  /// בניגוד לגיבוי-דריסה שבו כל העלאה הייתה מוחקת שינויים שלא הגיעו
  /// עדיין מהצד השני.
  List<Appointment> _merge(
      List<Appointment> local, List<Appointment> remote) {
    final map = {for (final a in local) a.id: a};
    for (final r in remote) {
      final existing = map[r.id];
      if (existing == null || r.updatedAt.isAfter(existing.updatedAt)) {
        map[r.id] = r;
      }
    }
    final cutoff = DateTime.now().subtract(_tombstoneRetention);
    final merged = map.values
        .where((a) => !a.isDeleted || a.deletedAt!.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return merged;
  }

  /// מיזוג רשימת תורים שהתקבלה מסנכרון (GitHub) עם המצב המקומי
  Future<void> mergeFromRemote(List<Appointment> remote) async {
    _appointments = _merge(_appointments, remote);
    notifyListeners();
    await _storage.saveAppointments(_appointments);
    unawaited(NotificationService.instance.rescheduleAll(appointments));
  }

  /// סנכרון ידני מלא (למשל כפתור "סנכרון עכשיו" במסך ההגדרות) - אותה
  /// לוגיקת מיזוג דו-כיוונית בדיוק כמו הסנכרון האוטומטי, כדי שלחיצה
  /// ידנית לא תדרוס בטעות שינויים שהגיעו ממכשיר אחר.
  Future<void> syncNow() => _syncUpload();

  /// מעלה את המצב הנוכחי ל-GitHub ברקע, ללא חסימת המשתמש. נקרא אוטומטית
  /// לאחר כל הוספה/עריכה/מחיקה, בתנאי שהוגדר סנכרון בהגדרות.
  ///
  /// לפני ההעלאה, קודם מורידים את הגרסה המרוחקת העדכנית וממזגים אותה
  /// עם המקומית (ולא פשוט דורסים אותה) - כדי לא לאבד שינויים שהגיעו
  /// ממכשיר אחר מאז הסנכרון האחרון.
  Future<void> _syncUpload() async {
    final service = _syncService;
    if (service == null) return;
    _syncStatus = SyncStatus.syncing;
    _syncError = null;
    notifyListeners();
    try {
      List<Appointment> toUpload = _appointments;
      try {
        final remote = await service.downloadAppointments();
        toUpload = _merge(_appointments, remote);
        if (!listEquals(toUpload, _appointments)) {
          _appointments = toUpload;
          await _storage.saveAppointments(_appointments);
        }
      } catch (_) {
        // אם ההורדה נכשלה (למשל אין רשת כרגע), עדיין מעלים את המצב
        // המקומי - עדיף סנכרון חלקי מאשר לא לסנכרן בכלל.
      }
      await service.uploadAppointments(toUpload);
      _syncStatus = SyncStatus.success;
      _lastSyncedAt = DateTime.now();
    } catch (e) {
      _syncStatus = SyncStatus.error;
      _syncError = e.toString();
    }
    notifyListeners();
  }

  /// רענון ידני (כפתור הרענון במסך הראשי): מוריד את הגרסה העדכנית
  /// מ-GitHub, ממזג אותה עם הנתונים המקומיים, ומעלה חזרה את התוצאה
  /// הממוזגת - כך שהסנכרון הוא דו-כיווני ולא רק "הורדה". אם לא הוגדר
  /// סנכרון, טוען מחדש רק מהאחסון המקומי של המכשיר.
  Future<void> refresh() async {
    final service = _syncService;
    if (service == null) {
      await load();
      return;
    }
    _syncStatus = SyncStatus.syncing;
    _syncError = null;
    notifyListeners();
    try {
      final remote = await service.downloadAppointments();
      final merged = _merge(_appointments, remote);
      _appointments = merged;
      notifyListeners();
      await _storage.saveAppointments(_appointments);
      unawaited(NotificationService.instance.rescheduleAll(appointments));
      // מעלים את התוצאה הממוזגת בחזרה, כדי שגם שינויים שהיו רק מקומיים
      // (שעדיין לא הגיעו ל-GitHub, למשל בגלל שהיה סנכרון אוטומטי כושל
      // קודם) יתפרסמו לצד השני.
      await service.uploadAppointments(merged);
      _syncStatus = SyncStatus.success;
      _lastSyncedAt = DateTime.now();
    } catch (e) {
      _syncStatus = SyncStatus.error;
      _syncError = e.toString();
    }
    notifyListeners();
  }
}
