import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../services/appointments_controller.dart';
import '../utils/hebrew_date_helper.dart';
import '../widgets/appointment_tile.dart';
import 'add_edit_appointment_screen.dart';

/// מסך "כל התורים" - מציג את כל התורים בטווח של שבוע או חודש (עברי) נוכחי,
/// עם אפשרות לדפדף קדימה/אחורה, בנוסף לתצוגת הלוח שנה החזותית במסך הראשי.
/// שימושי כשרוצים "לראות הכל ברצף" בלי ללחוץ יום-יום בלוח השנה.
class AppointmentsListScreen extends StatefulWidget {
  const AppointmentsListScreen({super.key});

  @override
  State<AppointmentsListScreen> createState() =>
      _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late DateTime _weekAnchor; // יום ראשון של השבוע המוצג
  late DateTime _monthAnchor; // עוגן (כל יום בתוך) החודש העברי המוצג

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    // מציאת יום ראשון האחרון (weekday: שני=1 ... ראשון=7)
    _weekAnchor =
        todayMidnight.subtract(Duration(days: todayMidnight.weekday % 7));
    _monthAnchor = todayMidnight;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekAnchor.add(Duration(days: i)));

  void _goPreviousWeek() =>
      setState(() => _weekAnchor = _weekAnchor.subtract(const Duration(days: 7)));

  void _goNextWeek() =>
      setState(() => _weekAnchor = _weekAnchor.add(const Duration(days: 7)));

  void _goPreviousMonth(HebrewMonthInfo info) =>
      setState(() => _monthAnchor = HebrewDateHelper.previousMonthAnchor(info));

  void _goNextMonth(HebrewMonthInfo info) =>
      setState(() => _monthAnchor = HebrewDateHelper.nextMonthAnchor(info));

  String _weekRangeLabel() {
    final start = _weekDays.first;
    final end = _weekDays.last;
    String fmt(DateTime d) => '${d.day}.${d.month}';
    return '${fmt(start)} - ${fmt(end)}.${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppointmentsController>();
    final monthInfo = HebrewDateHelper.monthInfoFor(_monthAnchor);

    return Scaffold(
      appBar: AppBar(
        title: const Text('כל התורים'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'השבוע'),
            Tab(text: 'החודש'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PeriodAppointmentsList(
            title: _weekRangeLabel(),
            onPrevious: _goPreviousWeek,
            onNext: _goNextWeek,
            days: _weekDays,
            controller: controller,
          ),
          _PeriodAppointmentsList(
            title: monthInfo.title,
            onPrevious: () => _goPreviousMonth(monthInfo),
            onNext: () => _goNextMonth(monthInfo),
            days: monthInfo.daysAsGregorian,
            controller: controller,
          ),
        ],
      ),
    );
  }
}

/// רשימת התורים בטווח נתון (ימי השבוע/החודש המוצג), מקובצת לפי יום,
/// עם סרגל דפדוף (חץ קודם/הבא) וכותרת הטווח מעל.
class _PeriodAppointmentsList extends StatelessWidget {
  final String title;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final List<DateTime> days;
  final AppointmentsController controller;

  const _PeriodAppointmentsList({
    required this.title,
    required this.onPrevious,
    required this.onNext,
    required this.days,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<DateTime, List<Appointment>>>[];
    var totalCount = 0;
    for (final day in days) {
      final appts = controller.forDay(day);
      if (appts.isNotEmpty) {
        entries.add(MapEntry(day, appts));
        totalCount += appts.length;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'לתקופה הקודמת',
                onPressed: onPrevious,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$totalCount תורים בטווח',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'לתקופה הבאה',
                onPressed: onNext,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available_outlined,
                          size: 44, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('אין תורים בטווח הזה',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                          child: Row(
                            children: [
                              Text(
                                HebrewDateHelper.weekdayName(entry.key),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${entry.key.day}.${entry.key.month}.${entry.key.year}',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '· ${entry.value.length} תורים',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        ...entry.value.map(
                          (appt) => AppointmentTile(
                            appointment: appt,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddEditAppointmentScreen(
                                  initialDate: entry.key,
                                  existing: appt,
                                ),
                              ),
                            ),
                            onDelete: () => controller.delete(appt.id),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
