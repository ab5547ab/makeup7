import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder_settings.dart';
import '../services/appointments_controller.dart';
import '../widgets/section_card.dart';

/// מסך הגדרות תזכורת: הפעלה/כיבוי, כמה זמן לפני התור לשלוח את התזכורת,
/// ובאיזו שעה. השינוי נשמר ומיושם מיד (כולל תזמון מחדש של כל התזכורות
/// הקיימות) - אין צורך בכפתור "שמור" נפרד.
class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  late ReminderSettings _settings;
  bool _saving = false;

  static const List<int> _daysOptions = [0, 1, 2, 3, 5, 7];

  @override
  void initState() {
    super.initState();
    _settings = context.read<AppointmentsController>().reminderSettings;
  }

  String _daysLabel(int days) {
    switch (days) {
      case 0:
        return 'ביום התור עצמו';
      case 1:
        return 'יום לפני';
      default:
        return '$days ימים לפני';
    }
  }

  Future<void> _apply(ReminderSettings updated) async {
    setState(() {
      _settings = updated;
      _saving = true;
    });
    await context.read<AppointmentsController>().applyReminderSettings(updated);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _settings.hour, minute: _settings.minute),
      helpText: 'שעת התזכורת',
    );
    if (picked == null) return;
    await _apply(_settings.copyWith(hour: picked.hour, minute: picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        '${_settings.hour.toString().padLeft(2, '0')}:${_settings.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('תזכורות לתורים'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'תזכורות לפני תורים',
            icon: Icons.notifications_active_outlined,
            children: [
              const Text(
                'האפליקציה יכולה לשלוח התראה במכשיר לפני כל תור, כדי '
                'שתוכלו להתארגן או להתקשר ללקוחה מראש אם צריך.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _settings.enabled,
                onChanged: (value) =>
                    _apply(_settings.copyWith(enabled: value)),
                title: const Text('תזכורות פעילות'),
                subtitle: const Text(
                  'כשכבוי, לא יישלחו התראות על תורים קיימים או חדשים',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const Divider(height: 24),
              Text(
                'מתי לשלוח את התזכורת',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _daysOptions.map((days) {
                  final selected = _settings.daysBefore == days;
                  return ChoiceChip(
                    label: Text(_daysLabel(days)),
                    selected: selected,
                    onSelected: !_settings.enabled
                        ? null
                        : (_) => _apply(_settings.copyWith(daysBefore: days)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: _settings.enabled,
                leading: const Icon(Icons.access_time),
                title: const Text('שעת התזכורת'),
                subtitle: Text('התזכורת תישלח בשעה $timeLabel'),
                trailing: TextButton(
                  onPressed: _settings.enabled ? _pickTime : null,
                  child: const Text('שינוי'),
                ),
                onTap: _settings.enabled ? _pickTime : null,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _settings.enabled
                            ? 'לדוגמה: ${_daysLabel(_settings.daysBefore)}, בשעה $timeLabel, תישלח התראה עם שם הלקוחה ושעת התור.'
                            : 'התזכורות כבויות כרגע - הפעילו למעלה כדי לקבל התראות.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
