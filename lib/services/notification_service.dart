import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/appointment.dart';
import '../models/reminder_settings.dart';

/// שירות תזכורות מקומיות: שולח התראה במכשיר לפני כל תור, כמות ימים ובשעה
/// הניתנים להגדרה במסך ההגדרות (ברירת מחדל: יום לפני, בשעה 09:00), כדי
/// שאפשר יהיה להתארגן/להתקשר ללקוחה מראש אם צריך.
/// עובד לגמרי מקומית במכשיר - לא תלוי ברשת או בסנכרון ל-GitHub.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// הגדרות התזכורת הנוכחיות - ניתנות לעדכון דרך configure() ממסך ההגדרות.
  /// ברירת המחדל תואמת להתנהגות המקורית: יום לפני, בשעה 09:00.
  ReminderSettings _settings = ReminderSettings.defaults();

  /// מעדכן את הגדרות התזכורת (אם פעילה, כמה ימים לפני, ובאיזו שעה). קריאה
  /// לפונקציה הזו לא מתזמנת מחדש בעצמה - יש לקרוא אחריה ל-rescheduleAll
  /// כדי שהשינוי ישתקף בתזכורות שכבר קיימות.
  void configure(ReminderSettings settings) {
    _settings = settings;
  }

  /// אתחול חד-פעמי - נקרא מ-main() עם עליית האפליקציה. מכין את מסד
  /// אזורי הזמן (חבילת timezone), ומבקש הרשאת התראות מהמשתמשת (נדרש
  /// החל מאנדרואיד 13).
  ///
  /// שימו לב: בכוונה לא תלויים בחבילת flutter_timezone כדי לזהות את
  /// אזור הזמן של המכשיר (מלבד היותה תלות נוספת, ה-API שלה משתנה
  /// לעיתים קרובות בין גרסאות). זה בסדר גמור כאן כי scheduleReminder
  /// בונה תמיד DateTime **מקומי** של המכשיר (המחשב לפי אזור הזמן
  /// שהמכשיר כבר מוגדר אליו) ומעביר אותו ל-TZDateTime.from(...) - וזו
  /// פונקציה ששומרת על הרגע המוחלט בזמן (millisecondsSinceEpoch) גם אם
  /// ה-location שסופק לה אינו "נכון" באופן פורמלי. מכיוון שאין כאן
  /// תזכורות חוזרות (recurring) שדורשות התאמת שעון-קיר לפי אזור זמן
  /// ספציפי, אין צורך לזהות את שם אזור הזמן ה-IANA המדויק.
  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
  }

  /// ממיר את מזהה התור (UUID, מחרוזת) למזהה מספרי יציב - כדי שתמיד
  /// אפשר יהיה לבטל/לעדכן את ההתראה הספציפית של תור מסוים.
  int _notificationId(String appointmentId) =>
      appointmentId.hashCode & 0x7fffffff;

  /// כותרת ההתראה, בהתאם להגדרת "כמה ימים לפני" הנוכחית
  String get _reminderTitle {
    switch (_settings.daysBefore) {
      case 0:
        return 'תזכורת: תור היום';
      case 1:
        return 'תזכורת: תור מחר';
      default:
        return 'תזכורת: תור בעוד ${_settings.daysBefore} ימים';
    }
  }

  /// מתזמן תזכורת לפני התור, לפי הגדרות המשתמשת (כמה ימים לפני ובאיזו
  /// שעה - ראו configure()). אם השעה הקבועה כבר עברה - למשל אם התור
  /// נוסף/נערך מאוחר יותר, או שהוגדרה תזכורת ביום התור עצמו - אבל התור
  /// עצמו עדיין בעתיד, התזכורת מתוזמנת לכמה שניות קדימה במקום לפספס
  /// אותה. אם התזכורות כבויות בהגדרות, או שהתור כבר עבר/מבוטל/נמחק,
  /// לא מתזמנים תזכורת (ומבטלים קיימת אם יש).
  Future<void> scheduleReminder(Appointment appointment) async {
    if (!_initialized) await init();

    if (!_settings.enabled ||
        appointment.isDeleted ||
        appointment.status == AppointmentStatus.cancelled) {
      await cancelReminder(appointment.id);
      return;
    }

    final apptDay = DateTime(appointment.dateTime.year,
        appointment.dateTime.month, appointment.dateTime.day);
    final targetDay = apptDay.subtract(Duration(days: _settings.daysBefore));
    var scheduled = DateTime(targetDay.year, targetDay.month, targetDay.day,
        _settings.hour, _settings.minute);

    final now = DateTime.now();
    if (scheduled.isBefore(now)) {
      if (appointment.dateTime.isAfter(now)) {
        // השעה הקבועה כבר עברה, אבל התור עצמו עדיין בעתיד -
        // שולחים את התזכורת בקרוב במקום לפספס אותה.
        scheduled = now.add(const Duration(seconds: 5));
      } else {
        // התור עצמו כבר עבר - אין טעם בתזכורת
        await cancelReminder(appointment.id);
        return;
      }
    }

    final time = DateFormat('HH:mm').format(appointment.dateTime);
    await _plugin.zonedSchedule(
      id: _notificationId(appointment.id),
      title: _reminderTitle,
      body:
          '${appointment.clientName} · בשעה $time · ${appointment.categoryData.name}',
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'appointment_reminders',
          'תזכורות לתורים',
          channelDescription: 'תזכורת לפני כל תור שנקבע בסטודיו',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: appointment.id,
    );
  }

  Future<void> cancelReminder(String appointmentId) async {
    await _plugin.cancel(id: _notificationId(appointmentId));
  }

  /// מבטל ומתזמן מחדש את כל התזכורות לפי רשימת התורים הנוכחית. נקרא
  /// עם עליית האפליקציה, ואחרי כל סנכרון/מיזוג - כדי לכסות גם מצבים
  /// שבהם תזמונים קודמים "אבדו" (למשל אחרי הפעלה מחדש של המכשיר,
  /// שמנקה התראות מתוזמנות ברמת המערכת), וגם תורים שהשתנו כתוצאה
  /// ממיזוג נתונים שהגיע ממכשיר אחר (ולכן לא עבר דרך add()/update()
  /// המקומיים, שם התזמון מתעדכן ממילא).
  Future<void> rescheduleAll(List<Appointment> appointments) async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
    if (!_settings.enabled) return;
    final now = DateTime.now();
    for (final appt in appointments) {
      if (appt.isDeleted) continue;
      if (appt.status == AppointmentStatus.cancelled) continue;
      if (appt.dateTime.isBefore(now)) continue;
      await scheduleReminder(appt);
    }
  }
}
