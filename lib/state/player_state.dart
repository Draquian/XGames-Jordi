import 'package:flutter/foundation.dart';

import '../data/local/device_identity.dart';
import '../data/local/player_cache.dart';
import '../network/connection_info.dart';
import '../network/player_client.dart';

/// Estat central del dispositiu d'un JUGADOR. Mai escriu punts ni
/// resultats: només mostra el que rep del màster i gestiona la connexió
/// (unir-se, reconnectar-se sol si cal).
class PlayerState extends ChangeNotifier {
  late final PlayerClient _client = PlayerClient(
    onJoined: _onJoined,
    onState: _onState,
    onKicked: _onKicked,
    onConnectionChanged: _onConnectionChanged,
    onJoinRejected: _onJoinRejected,
  );

  String? _playerId;
  bool _connected = false;
  bool _kicked = false;
  String? _joinRejectedReason;
  Map<String, Object?>? _lastState;

  String? get playerId => _playerId;
  bool get connected => _connected;
  bool get kicked => _kicked;
  String? get joinRejectedReason => _joinRejectedReason;
  bool get hasJoined => _playerId != null;

  String get sessionName =>
      (_lastState?['session'] as Map?)?['name'] as String? ?? '';
  String get myName => (_lastState?['me'] as Map?)?['name'] as String? ?? '';
  int get myTotalPoints =>
      (_lastState?['me'] as Map?)?['totalPoints'] as int? ?? 0;

  /// Noms i estat de la resta de jugadors (mai els seus punts).
  List<Map<String, Object?>> get roster {
    final list = _lastState?['players'] as List?;
    if (list == null) return const [];
    return list
        .map((e) => Map<String, Object?>.from(e as Map))
        .toList(growable: false);
  }

  Future<void> joinSession({
    required ConnectionInfo connectionInfo,
    required String playerName,
  }) async {
    _kicked = false;
    _joinRejectedReason = null;
    final deviceId = await DeviceIdentity.getOrCreate();
    await PlayerCache.saveConnection(SavedConnection(
      sessionId: connectionInfo.sessionId,
      playerName: playerName,
      host: connectionInfo.host,
      port: connectionInfo.port,
      joinCode: connectionInfo.joinCode,
    ));
    await _client.connect(
      connectionInfo: connectionInfo,
      deviceId: deviceId,
      playerName: playerName,
    );
  }

  /// Intenta reconnectar-se sol amb les dades de l'última sessió a la qual
  /// es va unir aquest dispositiu (útil en reobrir l'app).
  Future<bool> tryAutoReconnect() async {
    final saved = await PlayerCache.loadConnection();
    if (saved == null) return false;
    final deviceId = await DeviceIdentity.getOrCreate();
    final info = ConnectionInfo(
      sessionId: saved.sessionId,
      sessionName: '',
      host: saved.host,
      port: saved.port,
      joinCode: saved.joinCode,
    );
    await _client.connect(
      connectionInfo: info,
      deviceId: deviceId,
      playerName: saved.playerName,
    );
    return true;
  }

  void _onJoined(String playerId, String sessionId) {
    _playerId = playerId;
    notifyListeners();
  }

  void _onState(Map<String, Object?> state) {
    _lastState = state;
    final me = state['me'] as Map?;
    if (me != null) {
      PlayerCache.saveLastMeSnapshot(Map<String, Object?>.from(me));
    }
    notifyListeners();
  }

  void _onKicked() {
    _kicked = true;
    notifyListeners();
  }

  void _onJoinRejected(String reason) {
    _joinRejectedReason = reason;
    notifyListeners();
  }

  void _onConnectionChanged(bool connected) {
    _connected = connected;
    notifyListeners();
  }

  void leaveSession() {
    _client.disconnect();
    PlayerCache.clearConnection();
    _playerId = null;
    _lastState = null;
    _connected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.disconnect();
    super.dispose();
  }
}
