/// הגדרות תזכורת לתורים - כמה זמן לפני התור לשלוח התראה, ובאיזו שעה.
class ReminderSettings {
  /// האם תזכורות פעילות בכלל
  final bool enabled;

  /// כמה ימים לפני התור לשלוח את התזכורת (0 = ביום התור עצמו)
  final int daysBefore;

  /// השעה שבה נשלחת התזכורת (24 שעות)
  final int hour;
  final int minute;

  const ReminderSettings({
    required this.enabled,
    required this.daysBefore,
    required this.hour,
    required this.minute,
  });

  /// ברירת המחדל המקורית של האפליקציה: יום לפני, בשעה 09:00
  factory ReminderSettings.defaults() => const ReminderSettings(
        enabled: true,
        daysBefore: 1,
        hour: 9,
        minute: 0,
      );

  ReminderSettings copyWith({
    bool? enabled,
    int? daysBefore,
    int? hour,
    int? minute,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      daysBefore: daysBefore ?? this.daysBefore,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'daysBefore': daysBefore,
        'hour': hour,
        'minute': minute,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    final defaults = ReminderSettings.defaults();
    return ReminderSettings(
      enabled: json['enabled'] as bool? ?? defaults.enabled,
      daysBefore: json['daysBefore'] as int? ?? defaults.daysBefore,
      hour: json['hour'] as int? ?? defaults.hour,
      minute: json['minute'] as int? ?? defaults.minute,
    );
  }
}
