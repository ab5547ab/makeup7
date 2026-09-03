import 'package:flutter/services.dart';

/// גשר (Method Channel) לקוד האנדרואיד הנייטיבי, המאפשר חיבור לרשת Wi-Fi
/// ספציפית לפני ביצוע סנכרון - שימושי כשהסטודיו עובד מול נתב ייעודי.
/// דורש אנדרואיד 10 (API 29) ומעלה.
///
/// החיבור נשאר פעיל (bound) בצד האנדרואיד כל עוד האפליקציה פתוחה, ומתנתק
/// אוטומטית רק כשהאפליקציה נסגרת - ראו MainActivity.kt.
class WifiService {
  static const platform = MethodChannel('com.mua.studiocalendar/wifi');

  static Future<bool> connectAndSync({
    required String ssid,
    required String password,
  }) async {
    if (ssid.trim().isEmpty) return false;
    try {
      final String result = await platform.invokeMethod('connectAndSync', {
        'ssid': ssid,
        'password': password,
      });
      return result == 'CONNECTED';
    } on PlatformException {
      return false;
    }
  }

  /// מנתק באופן יזום את הרשת הייעודית (למשל אם רוצים לאלץ ניתוק).
  /// בשימוש רגיל אין צורך לקרוא לזה - הניתוק קורה אוטומטית בסגירת האפליקציה.
  static Future<void> disconnect() async {
    try {
      await platform.invokeMethod('disconnectWifi');
    } on PlatformException {
      // אין צורך לטפל - אם הניתוק נכשל, מדובר לרוב במצב שכבר מנותק
    }
  }
}
