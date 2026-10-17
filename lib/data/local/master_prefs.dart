import 'package:shared_preferences/shared_preferences.dart';

/// Preferències locals mínimes del dispositiu del MÀSTER.
class MasterPrefs {
  static const _lastSeenMessageKey =
      'navidad_jordi_master_last_seen_message_ms';

  /// Marca de temps (ms) del darrer missatge de jugador que el màster ja ha
  /// vist; serveix per comptar els missatges sense llegir.
  static Future<int> loadLastSeenMessageMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSeenMessageKey) ?? 0;
  }

  static Future<void> saveLastSeenMessageMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeenMessageKey, ms);
  }
}
