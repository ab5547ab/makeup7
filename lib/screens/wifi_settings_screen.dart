import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/wifi_connection_controller.dart';
import '../widgets/section_card.dart';

/// מסך הגדרות חיבור Wi-Fi בלבד - מנותק לגמרי מהגדרות הסנכרון ל-GitHub.
/// החיבור עצמו מנוהל ברמת האפליקציה (WifiConnectionController) כדי
/// שיישאר פעיל כל עוד האפליקציה פתוחה, גם אם יוצאים מהמסך הזה.
class WifiSettingsScreen extends StatefulWidget {
  const WifiSettingsScreen({super.key});

  @override
  State<WifiSettingsScreen> createState() => _WifiSettingsScreenState();
}

class _WifiSettingsScreenState extends State<WifiSettingsScreen> {
  final _storage = StorageService();
  final _ssidCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberWifi = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final wifi = await _storage.loadWifiCredentials();
    if (!mounted) return;
    setState(() {
      _ssidCtrl.text = wifi['ssid'] ?? '';
      _passwordCtrl.text = wifi['password'] ?? '';
    });
  }

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _connect() async {
    final ssid = _ssidCtrl.text.trim();
    if (ssid.isEmpty) {
      _showSnack('נא להזין שם רשת (SSID)');
      return;
    }

    setState(() => _isConnecting = true);

    if (_rememberWifi) {
      await _storage.saveWifiCredentials(
        ssid: ssid,
        password: _passwordCtrl.text,
      );
    } else {
      await _storage.clearWifiCredentials();
    }

    if (!mounted) return;
    final wifiController = context.read<WifiConnectionController>();
    wifiController.applyCredentials(ssid: ssid, password: _passwordCtrl.text);
    final ok = await wifiController.connect();

    if (!mounted) return;
    setState(() => _isConnecting = false);
    _showSnack(ok
        ? 'מחובר לרשת - החיבור יישאר פעיל כל עוד האפליקציה פתוחה'
        : 'שגיאה בחיבור לרשת: ${wifiController.error ?? ''}');
  }

  Future<void> _forget() async {
    await _storage.clearWifiCredentials();
    if (!mounted) return;
    context.read<WifiConnectionController>().clearCredentials();
    setState(() {
      _ssidCtrl.clear();
      _passwordCtrl.clear();
      _rememberWifi = false;
    });
    _showSnack('פרטי הרשת השמורים נמחקו');
  }

  @override
  Widget build(BuildContext context) {
    final wifiController = context.watch<WifiConnectionController>();

    return Scaffold(
      appBar: AppBar(title: const Text('חיבור לרשת Wi-Fi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'חיבור לרשת Wi-Fi של הסטודיו',
            icon: Icons.wifi,
            children: [
              const Text(
                'הרשת הזו תישאר מחוברת באופן קבוע כל עוד האפליקציה פתוחה - '
                'כך שהסנכרון תמיד יהיה מול הנתב הייעודי בזמן אמת. החיבור '
                'מתנתק אוטומטית רק כשסוגרים את האפליקציה.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 14),
              _WifiStatusBanner(controller: wifiController),
              const SizedBox(height: 16),
              TextField(
                controller: _ssidCtrl,
                decoration: const InputDecoration(labelText: 'שם רשת (SSID)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'סיסמת רשת',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              CheckboxListTile(
                value: _rememberWifi,
                onChanged: (value) =>
                    setState(() => _rememberWifi = value ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text('זכור פרטי רשת זו במכשיר'),
                subtitle: const Text(
                  'נשמר מקומית בלבד, כדי שלא תצטרכו להזין שוב בפעם הבאה',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _connect,
                      icon: _isConnecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.wifi_tethering),
                      label: const Text('התחבר לרשת'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'שכח פרטי רשת שמורים',
                    onPressed: _forget,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WifiStatusBanner extends StatelessWidget {
  final WifiConnectionController controller;

  const _WifiStatusBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;
    late final String text;

    switch (controller.status) {
      case WifiConnectionStatus.notConfigured:
        icon = Icons.wifi_off_outlined;
        color = Colors.grey.shade600;
        text = 'עדיין לא הוגדרה רשת';
        break;
      case WifiConnectionStatus.disconnected:
        icon = Icons.wifi_off;
        color = Colors.orange.shade800;
        text = 'מוגדר, אך לא מחובר כרגע';
        break;
      case WifiConnectionStatus.connecting:
        icon = Icons.wifi_find;
        color = Colors.blue.shade700;
        text = 'מתחבר לרשת...';
        break;
      case WifiConnectionStatus.connected:
        icon = Icons.wifi;
        color = Colors.green.shade700;
        text = 'מחובר · החיבור פעיל כל עוד האפליקציה פתוחה';
        break;
      case WifiConnectionStatus.error:
        icon = Icons.error_outline;
        color = Colors.red.shade700;
        text = controller.error ?? 'שגיאת חיבור לרשת';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
          ),
        ],
      ),
    );
  }
}
