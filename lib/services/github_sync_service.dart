import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/appointment.dart';

/// שירות סנכרון מול קובץ JSON בריפוזיטורי GitHub פרטי.
/// משמש כגיבוי/שחזור פשוט - אין צורך בשרת משלכם.
///
/// הערה: יש להשתמש ב"Personal Access Token" עם הרשאות "repo" בלבד,
/// וכדאי שהריפו יהיה פרטי (Private) כדי לשמור על פרטיות פרטי הלקוחות.
class GitHubSyncService {
  final String token;
  final String owner;
  final String repo;
  final String path;

  GitHubSyncService({
    required this.token,
    required this.owner,
    required this.repo,
    required this.path,
  });

  Uri get _url =>
      Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$path');

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
      };

  /// מעלה את כל התורים לקובץ ב-GitHub (יוצר או מעדכן)
  Future<void> uploadAppointments(List<Appointment> appointments) async {
    String? sha;
    final getResponse = await http.get(_url, headers: _headers);
    if (getResponse.statusCode == 200) {
      sha = jsonDecode(getResponse.body)['sha'] as String?;
    } else if (getResponse.statusCode != 404) {
      throw GitHubSyncException(
          'שגיאה בבדיקת הקובץ הקיים (קוד ${getResponse.statusCode})');
    }

    final jsonList = appointments.map((a) => a.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
    final contentBase64 = base64Encode(utf8.encode(jsonString));

    final body = {
      'message': 'סנכרון תורים אוטומטי - ${DateTime.now().toIso8601String()}',
      'content': contentBase64,
      if (sha != null) 'sha': sha,
    };

    final putResponse = await http.put(
      _url,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (putResponse.statusCode != 200 && putResponse.statusCode != 201) {
      throw GitHubSyncException(
          'שגיאה בהעלאה ל-GitHub (קוד ${putResponse.statusCode}): '
          '${_extractMessage(putResponse.body)}');
    }
  }

  /// מוריד את התורים מהקובץ ב-GitHub לצורך מיזוג. אם הקובץ עדיין לא קיים
  /// (למשל בסנכרון הראשון אי-פעם) מחזיר רשימה ריקה במקום לזרוק שגיאה -
  /// זהו מצב לגיטימי ולא תקלה, וכך המיזוג הדו-כיווני עדיין עובד כרגיל.
  Future<List<Appointment>> downloadAppointments() async {
    final response = await http.get(_url, headers: _headers);

    if (response.statusCode == 404) {
      return [];
    }
    if (response.statusCode != 200) {
      throw GitHubSyncException(
          'שגיאה בהורדה מ-GitHub (קוד ${response.statusCode}): '
          '${_extractMessage(response.body)}');
    }

    final data = jsonDecode(response.body);
    final contentBase64 = (data['content'] as String).replaceAll('\n', '');
    final decoded = utf8.decode(base64Decode(contentBase64));
    final list = jsonDecode(decoded) as List<dynamic>;
    return list
        .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  String _extractMessage(String body) {
    try {
      final data = jsonDecode(body);
      return data['message']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}

class GitHubSyncException implements Exception {
  final String message;
  GitHubSyncException(this.message);
  @override
  String toString() => message;
}
