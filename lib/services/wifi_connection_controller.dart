import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import 'wifi_service.dart';

/// מצב החיבור לרשת ה-Wi-Fi הייעודית של הסטודיו.
enum WifiConnectionStatus {
  /// לא הוגדרו פרטי רשת בהגדרות
  notConfigured,

  /// מוגדר, אך אין כרגע חיבור פעיל
  disconnected,

  /// מתבצע כרגע ניסיון חיבור
  connecting,

  /// מחוברים בהצלחה
  connected,

  /// ניסיון החיבור האחרון נכשל
  error,
}

/// אחראי יחיד על חיבור ה-Wi-Fi של הסטודיו, בנפרד לגמרי מהגדרות
/// הסנכרון ל-GitHub. זהו קונטרולר ברמת האפליקציה (Provider) כדי שהחיבור
/// יישאר "חי" כל עוד האפליקציה פתוחה, ללא תלות במסך שממנו הופעל -
/// כולל התחברות אוטומטית עם פתיחת האפליקציה, וניסיון חיבור בכל לחיצה
/// על כפתור הסנכרון. הניתוק בפועל (ברמת המכשיר) קורה רק כשהאפליקציה
/// נסגרת (ראו MainActivity.kt בצד האנדרואיד).
class WifiConnectionController extends ChangeNotifier {
  final StorageService _storage = StorageService();

  String? _ssid;
  String? _password;
  WifiConnectionStatus _status = WifiConnectionStatus.notConfigured;
  String? _error;

  WifiConnectionStatus get status => _status;
  String? get error => _error;
  String? get ssid => _ssid;
  bool get isConfigured => (_ssid ?? '').trim().isNotEmpty;
  bool get isConnected => _status == WifiConnectionStatus.connected;

  /// נטען פעם אחת בעליית האפליקציה. רק טוען את פרטי הרשת השמורים -
  /// **לא** מתחבר אוטומטית. החיבור בפועל מתבצע רק כשהמשתמש לוחץ על
  /// כפתור הרענון/סנכרון (ראו ensureConnected, שנקרא מ-_handleRefresh
  /// במסך הראשי).
  Future<void> load() async {
    final creds = await _storage.loadWifiCredentials();
    _ssid = creds['ssid'];
    _password = creds['password'];
    _status = isConfigured
        ? WifiConnectionStatus.disconnected
        : WifiConnectionStatus.notConfigured;
    notifyListeners();
  }

  /// נקרא ממסך הגדרות ה-Wi-Fi מיד לאחר שמירת פרטי רשת חדשים/מעודכנים
  void applyCredentials({required String ssid, required String password}) {
    _ssid = ssid;
    _password = password;
    _status = isConfigured
        ? WifiConnectionStatus.disconnected
        : WifiConnectionStatus.notConfigured;
    _error = null;
    notifyListeners();
  }

  void clearCredentials() {
    _ssid = null;
    _password = null;
    _status = WifiConnectionStatus.notConfigured;
    _error = null;
    notifyListeners();
  }

  /// מוודא שיש חיבור פעיל - אם כבר מחוברים, לא עושה כלום.
  /// זה מה שנקרא בכל לחיצה על כפתור הסנכרון.
  Future<bool> ensureConnected() async {
    if (!isConfigured) return false;
    if (_status == WifiConnectionStatus.connected) return true;
    return connect();
  }

  /// מתחבר (או מתחבר מחדש, למשל אחרי שינוי סיסמה) לרשת המוגדרת.
  Future<bool> connect() async {
    if (!isConfigured) return false;
    _status = WifiConnectionStatus.connecting;
    _error = null;
    notifyListeners();
    try {
      final ok = await WifiService.connectAndSync(
        ssid: _ssid!,
        password: _password ?? '',
      );
      _status = ok ? WifiConnectionStatus.connected : WifiConnectionStatus.error;
      if (!ok) _error = 'לא ניתן היה להתחבר לרשת';
    } catch (e) {
      _status = WifiConnectionStatus.error;
      _error = e.toString();
    }
    notifyListeners();
    return _status == WifiConnectionStatus.connected;
  }
}
