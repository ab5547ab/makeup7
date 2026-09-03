import 'package:kosher_dart/kosher_dart.dart';

/// עוזר לחישובי תאריך עברי - עוטף את kosher_dart בצורה נוחה למסך הלוח שנה.
///
/// הגישה: כל הניווט בין חודשים מתבצע דרך התאריך הגרגוריאני (שהוא הבסיס
/// האמיתי לאחסון הנתונים), וממנו נגזר בכל פעם התאריך העברי המתאים.
/// כך נמנעים לחלוטין מהצורך לממש ידנית את חוקי גלגול השנה/חודש העברי
/// (עיבור, חשוון/כסלו מלאים או חסרים וכו') - הספרייה עושה זאת בשבילנו.
class HebrewDateHelper {
  static final HebrewDateFormatter _formatter = HebrewDateFormatter()
    ..hebrewFormat = true
    ..useGershGershayim = true;

  static JewishDate _jewishDateFor(DateTime day) {
    return JewishDate()..setDate(DateTime(day.year, day.month, day.day));
  }

  /// התאריך העברי המלא, לדוגמה: "י״א באלול תשפ״ו"
  static String fullHebrewDate(DateTime day) {
    return _formatter.format(_jewishDateFor(day));
  }

  /// שם היום בשבוע בעברית
  static String weekdayName(DateTime day) {
    return _formatter.formatDayOfWeek(_jewishDateFor(day));
  }

  /// היום בחודש העברי בגימטריה, לדוגמה: "י״א"
  static String hebrewDayOfMonth(DateTime day) {
    final jd = _jewishDateFor(day);
    return _formatter.formatHebrewNumber(jd.getJewishDayOfMonth());
  }

  /// מידע מלא על "החודש העברי המכיל" את התאריך הנתון
  static HebrewMonthInfo monthInfoFor(DateTime anyDayInMonth) {
    final jd = _jewishDateFor(anyDayInMonth);
    final dayOfMonth = jd.getJewishDayOfMonth();
    final daysInMonth = jd.getDaysInJewishMonth();
    final firstDayGregorian = DateTime(
            anyDayInMonth.year, anyDayInMonth.month, anyDayInMonth.day)
        .subtract(Duration(days: dayOfMonth - 1));

    final firstDayJewishDate = _jewishDateFor(firstDayGregorian);
    final monthName = _formatter.formatMonth(firstDayJewishDate);
    final yearGematria =
        _formatter.formatHebrewNumber(firstDayJewishDate.getJewishYear());

    return HebrewMonthInfo(
      monthName: monthName,
      yearGematria: yearGematria,
      firstDayGregorian: firstDayGregorian,
      daysInMonth: daysInMonth,
    );
  }

  /// עוגן (כל תאריך בתוך החודש) של החודש העברי הבא
  static DateTime nextMonthAnchor(HebrewMonthInfo info) {
    return info.firstDayGregorian.add(Duration(days: info.daysInMonth));
  }

  /// עוגן (כל תאריך בתוך החודש) של החודש העברי הקודם
  static DateTime previousMonthAnchor(HebrewMonthInfo info) {
    return info.firstDayGregorian.subtract(const Duration(days: 1));
  }
}

class HebrewMonthInfo {
  final String monthName;
  final String yearGematria;
  final DateTime firstDayGregorian;
  final int daysInMonth;

  HebrewMonthInfo({
    required this.monthName,
    required this.yearGematria,
    required this.firstDayGregorian,
    required this.daysInMonth,
  });

  String get title => '$monthName $yearGematria';

  List<DateTime> get daysAsGregorian => List.generate(
        daysInMonth,
        (i) => firstDayGregorian.add(Duration(days: i)),
      );
}
