package com.mua.makeup_calendar

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * החיבור לרשת ה-Wi-Fi הייעודית של הסטודיו נשאר פעיל (bound) כל עוד
 * האפליקציה פתוחה - כדי שהסנכרון יהיה תמיד מול הנתב הנכון בזמן אמת.
 * החיבור משוחרר אוטומטית רק כש-Activity נהרס (סגירת האפליקציה), ב-onDestroy.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.mua.studiocalendar/wifi"

    private var connectivityManager: ConnectivityManager? = null
    private var activeCallback: ConnectivityManager.NetworkCallback? = null
    private var activeSsid: String? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connectAndSync" -> {
                        val ssid = call.argument<String>("ssid") ?: ""
                        val password = call.argument<String>("password") ?: ""
                        connectToWifi(ssid, password, result)
                    }
                    "disconnectWifi" -> {
                        releaseWifiConnection()
                        result.success("DISCONNECTED")
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun connectToWifi(ssid: String, password: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("UNSUPPORTED", "גרסת אנדרואיד אינה נתמכת", null)
            return
        }

        // אם כבר מחוברים לאותה רשת - אין צורך לבקש חיבור חדש
        if (activeSsid == ssid && activeCallback != null) {
            result.success("CONNECTED")
            return
        }

        // מנתקים חיבור קודם (אם היה לרשת אחרת) לפני שמבקשים חיבור חדש
        releaseWifiConnection()

        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .setWpa2Passphrase(password)
            .build()

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .setNetworkSpecifier(specifier)
            .build()

        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        connectivityManager = manager

        var resultSent = false
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                super.onAvailable(network)
                // קושר את כל תעבורת האפליקציה לרשת הזו, וממשיך להחזיק בה
                // (לא משחררים כאן) כדי שהחיבור יישאר חי כל עוד האפליקציה פתוחה.
                manager.bindProcessToNetwork(network)
                if (!resultSent) {
                    resultSent = true
                    result.success("CONNECTED")
                }
            }

            override fun onLost(network: Network) {
                super.onLost(network)
                // הרשת נופלת (למשל יצאנו מהטווח) - משחררים את הקישור כדי
                // שהמכשיר יוכל לחזור לרשת רגילה/סלולר, עד לניסיון חיבור הבא.
                if (activeCallback === this) {
                    manager.bindProcessToNetwork(null)
                    activeSsid = null
                }
            }

            override fun onUnavailable() {
                super.onUnavailable()
                if (!resultSent) {
                    resultSent = true
                    result.error("UNAVAILABLE", "לא ניתן להתחבר לרשת", null)
                }
            }
        }

        activeCallback = callback
        activeSsid = ssid
        manager.requestNetwork(request, callback)
    }

    /** משחרר את הבקשה הפעילה לרשת, אם קיימת */
    private fun releaseWifiConnection() {
        val manager = connectivityManager
        val callback = activeCallback
        if (manager != null && callback != null) {
            try {
                manager.bindProcessToNetwork(null)
                manager.unregisterNetworkCallback(callback)
            } catch (_: IllegalArgumentException) {
                // הקולבק כבר לא היה רשום - אין צורך לעשות דבר
            }
        }
        activeCallback = null
        activeSsid = null
    }

    override fun onDestroy() {
        // סגירת האפליקציה: מנתקים את החיבור הייעודי לרשת הסטודיו
        releaseWifiConnection()
        super.onDestroy()
    }
}
