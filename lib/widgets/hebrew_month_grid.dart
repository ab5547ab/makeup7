import 'package:flutter/material.dart';
import '../utils/hebrew_date_helper.dart';

/// לוח שנה חודשי המבוסס על החודש העברי (ולא הלועזי) כתצוגה ראשית.
/// ימי השבוע מיושרים לפי יום השבוע הגרגוריאני הרגיל (א'-ש'), בעוד שהחודש
/// והמספור בתוך התאים הם עבריים.
class HebrewMonthGrid extends StatelessWidget {
  final HebrewMonthInfo monthInfo;
  final DateTime selectedDay;
  final DateTime today;
  final Set<DateTime> daysWithAppointments;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const HebrewMonthGrid({
    super.key,
    required this.monthInfo,
    required this.selectedDay,
    required this.today,
    required this.daysWithAppointments,
    required this.onDaySelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  static const _weekdayLabels = ['א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ש'];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final days = monthInfo.daysAsGregorian;
    // יישור לפי יום השבוע הגרגוריאני של היום הראשון בחודש (ראשון=0)
    final leadingBlanks = days.first.weekday % 7;

    final primary = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        // גודל התא מחושב לפי הרוחב הזמין בפועל, כך שהלוח מתאים את עצמו
        // לכל גודל מסך (מכשירים קטנים כמו גם טאבלטים).
        final availableWidth = constraints.maxWidth - 12;
        final cellWidth = (availableWidth / 7).clamp(32.0, 72.0);
        final isTiny = constraints.maxWidth < 340;

        final primaryFontSize = (cellWidth * 0.30).clamp(11.0, 16.0);
        final secondaryFontSize = (cellWidth * 0.20).clamp(8.0, 11.0);
        final dotSize = (cellWidth * 0.09).clamp(4.0, 6.0);
        final headerFontSize = isTiny ? 17.0 : 20.0;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: onPreviousMonth,
                    tooltip: 'חודש עברי קודם',
                  ),
                  Expanded(
                    child: Text(
                      monthInfo.title,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: primary, fontSize: headerFontSize),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: onNextMonth,
                    tooltip: 'חודש עברי הבא',
                  ),
                ],
              ),
            ),
            Row(
              children: _weekdayLabels
                  .map((label) => Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: secondaryFontSize + 2,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.95,
              ),
              itemCount: leadingBlanks + days.length,
              itemBuilder: (context, index) {
                if (index < leadingBlanks) return const SizedBox.shrink();
                final day = days[index - leadingBlanks];
                final isSelected = _isSameDay(day, selectedDay);
                final isToday = _isSameDay(day, today);
                final hasAppointments = daysWithAppointments
                    .any((d) => _isSameDay(d, day));

                return GestureDetector(
                  onTap: () => onDaySelected(day),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: EdgeInsets.all(isTiny ? 2 : 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary
                          : isToday
                              ? Theme.of(context)
                                  .colorScheme
                                  .tertiary
                                  .withOpacity(0.35)
                              : null,
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          HebrewDateHelper.hebrewDayOfMonth(day),
                          style: TextStyle(
                            fontWeight: isSelected || isToday
                                ? FontWeight.bold
                                : null,
                            color: isSelected ? Colors.white : null,
                            fontSize: primaryFontSize,
                          ),
                        ),
                        Text(
                          '${day.day}/${day.month}',
                          style: TextStyle(
                            fontSize: secondaryFontSize,
                            color: isSelected
                                ? Colors.white70
                                : Colors.grey.shade500,
                          ),
                        ),
                        if (hasAppointments)
                          Container(
                            margin: const EdgeInsets.only(top: 1),
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}
