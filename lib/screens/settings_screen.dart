import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/appointments_controller.dart';
import '../services/wifi_connection_controller.dart';
import 'github_sync_settings_screen.dart';
import 'reminder_settings_screen.dart';
import 'wifi_settings_screen.dart';

/// מסך הגדרות ראשי - "רכזת" שמפנה למסכי הגדרות נפרדים ועצמאיים: תזכורות
/// לתורים, סנכרון ל-GitHub, וחיבור לרשת Wi-Fi. כל נושא מנוהל בנפרד
/// לגמרי, כדי שאפשר יהיה להגדיר/לשנות כל אחד מהם בלי להשפיע על האחרים.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _wifiSubtitle(WifiConnectionController wifi) {
    switch (wifi.status) {
      case WifiConnectionStatus.notConfigured:
        return 'לא מוגדר';
      case WifiConnectionStatus.disconnected:
        return 'מוגדר, לא מחובר כרגע';
      case WifiConnectionStatus.connecting:
        return 'מתחבר...';
      case WifiConnectionStatus.connected:
        return 'מחובר (${wifi.ssid ?? ''})';
      case WifiConnectionStatus.error:
        return 'שגיאת חיבור';
    }
  }

  String _reminderSubtitle(AppointmentsController controller) {
    final settings = controller.reminderSettings;
    if (!settings.enabled) return 'כבויות';
    final time =
        '${settings.hour.toString().padLeft(2, '0')}:${settings.minute.toString().padLeft(2, '0')}';
    switch (settings.daysBefore) {
      case 0:
        return 'ביום התור עצמו · $time';
      case 1:
        return 'יום לפני · $time';
      default:
        return '${settings.daysBefore} ימים לפני · $time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final wifi = context.watch<WifiConnectionController>();
    final appointments = context.watch<AppointmentsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('הגדרות')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('תזכורות לתורים'),
              subtitle: Text(_reminderSubtitle(appointments)),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ReminderSettingsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('סנכרון ל-GitHub'),
              subtitle: const Text('סנכרון דו-כיווני אוטומטי בין המכשירים'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const GithubSyncSettingsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                wifi.isConnected ? Icons.wifi : Icons.wifi_outlined,
                color: wifi.isConnected ? Colors.green.shade700 : null,
              ),
              title: const Text('חיבור לרשת Wi-Fi'),
              subtitle: Text(_wifiSubtitle(wifi)),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const WifiSettingsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
