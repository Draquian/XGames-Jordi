import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Dades mínimes que necessita el dispositiu d'un JUGADOR per intentar
/// reconnectar-se sol a la partida (per exemple, si es tanca l'app i la
/// torna a obrir).
class SavedConnection {
  final String sessionId;
  final String playerName;
  final String host;
  final int port;
  final String joinCode;

  const SavedConnection({
    required this.sessionId,
    required this.playerName,
    required this.host,
    required this.port,
    required this.joinCode,
  });

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'playerName': playerName,
        'host': host,
        'port': port,
        'joinCode': joinCode,
      };

  factory SavedConnection.fromJson(Map<String, Object?> json) {
    return SavedConnection(
      sessionId: json['sessionId'] as String,
      playerName: json['playerName'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      joinCode: json['joinCode'] as String,
    );
  }
}

/// Persistència local, molt lleugera, del dispositiu d'un JUGADOR. A
/// diferència del màster, el jugador no té una base de dades relacional:
/// només necessita recordar com reconnectar-se i la darrera foto dels seus
/// propis resultats, per poder-los consultar encara que perdi la connexió
/// un moment.
class PlayerCache {
  static const _connectionKey = 'navidad_jordi_saved_connection';
  static const _lastSnapshotKey = 'navidad_jordi_last_me_snapshot';

  static Future<void> saveConnection(SavedConnection connection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_connectionKey, jsonEncode(connection.toJson()));
  }

  static Future<SavedConnection?> loadConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_connectionKey);
    if (raw == null) return null;
    return SavedConnection.fromJson(
      Map<String, Object?>.from(jsonDecode(raw) as Map),
    );
  }

  static Future<void> clearConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_connectionKey);
  }

  /// Darrer resum ("me") rebut del màster: nom, punts, historial. Es
  /// mostra si el jugador consulta les seves dades sense connexió.
  static Future<void> saveLastMeSnapshot(Map<String, Object?> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSnapshotKey, jsonEncode(snapshot));
  }

  static Future<Map<String, Object?>?> loadLastMeSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSnapshotKey);
    if (raw == null) return null;
    return Map<String, Object?>.from(jsonDecode(raw) as Map);
  }

  static const _lastSeenMessageKey = 'navidad_jordi_last_seen_message_ms';

  /// Marca de temps (ms) del darrer missatge rebut que el jugador ja ha
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
