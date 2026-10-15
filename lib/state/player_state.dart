import 'dart:async';

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
    onSendResult: _onSendResult,
  );

  String? _playerId;
  bool _connected = false;
  bool _kicked = false;
  String? _joinRejectedReason;
  Map<String, Object?>? _lastState;

  // Missatges privats
  Completer<String?>? _pendingSend;
  final StreamController<Map<String, Object?>> _incomingController =
      StreamController<Map<String, Object?>>.broadcast();
  final Set<String> _knownMessageIds = {};
  bool _inboxInitialized = false;
  int _lastSeenMessageMs = 0;
  bool _disposed = false;

  PlayerState() {
    PlayerCache.loadLastSeenMessageMs().then((ms) {
      if (_disposed) return;
      _lastSeenMessageMs = ms;
      notifyListeners();
    });
  }

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

  /// Els missatges privats d'aquest jugador (enviats i rebuts), del més
  /// antic al més nou. Cada entrada té `id`, `direction` ('in' o 'out'),
  /// `otherPlayerId`, `otherName`, `body`, `points` i `createdAtMs`.
  List<Map<String, Object?>> get inbox {
    final list = _lastState?['inbox'] as List?;
    if (list == null) return const [];
    return list
        .map((e) => Map<String, Object?>.from(e as Map))
        .toList(growable: false);
  }

  /// Missatges rebuts que encara no s'han vist a la pantalla de missatges.
  int get unreadMessages => inbox
      .where((m) =>
          m['direction'] == 'in' &&
          ((m['createdAtMs'] as int?) ?? 0) > _lastSeenMessageMs)
      .length;

  /// Avisa cada vegada que arriba un missatge nou (només mentre l'app és
  /// oberta i connectada).
  Stream<Map<String, Object?>> get incomingMessages =>
      _incomingController.stream;

  /// El propi historial: una barreja de resultats de minijocs i
  /// ajustaments manuals del màster, en ordre cronològic. Cada entrada té
  /// `type` ('result' o 'adjustment'), `label`, `position` (només als
  /// resultats) i `points`.
  List<Map<String, Object?>> get myHistory {
    final list = (_lastState?['me'] as Map?)?['history'] as List?;
    if (list == null) return const [];
    return list
        .map((e) => Map<String, Object?>.from(e as Map))
        .toList(growable: false);
  }

  /// El minijoc que el màster té actiu ara mateix, o `null` si cap.
  Map<String, Object?>? get activeMinigame {
    final session = _lastState?['session'] as Map?;
    final currentId = session?['currentMinigameId'] as String?;
    if (currentId == null) return null;
    final list = _lastState?['minigames'] as List?;
    if (list == null) return null;
    for (final raw in list) {
      final m = Map<String, Object?>.from(raw as Map);
      if (m['id'] == currentId) return m;
    }
    return null;
  }

  /// `true` quan el màster ha finalitzat la partida: és el moment de
  /// mostrar el podi final a tothom.
  bool get sessionFinished =>
      (_lastState?['session'] as Map?)?['status'] == 'finished';

  /// La classificació final (nom + punts de TOTS els jugadors), només
  /// disponible un cop la partida ha finalitzat.
  List<Map<String, Object?>> get finalStandings {
    final list = _lastState?['finalStandings'] as List?;
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

  /// Envia un missatge privat al jugador `toPlayerId` i, si `points` > 0,
  /// li transfereix aquests punts dels teus. Retorna `null` si el màster
  /// ho ha acceptat, o un codi d'error.
  Future<String?> sendMessage({
    required String toPlayerId,
    required String body,
    required int points,
  }) async {
    if (_pendingSend != null) return 'busy';
    final sent = _client.sendMessage(
      toPlayerId: toPlayerId,
      body: body,
      points: points,
    );
    if (!sent) return 'offline';
    final completer = Completer<String?>();
    _pendingSend = completer;
    try {
      return await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => 'timeout',
      );
    } finally {
      _pendingSend = null;
    }
  }

  void _onSendResult(bool ok, String? reason) {
    final pending = _pendingSend;
    if (pending != null && !pending.isCompleted) {
      pending.complete(ok ? null : (reason ?? 'error'));
    }
  }

  /// Marca com a vistos tots els missatges rebuts fins ara.
  void markMessagesSeen() {
    var newest = _lastSeenMessageMs;
    for (final m in inbox) {
      if (m['direction'] != 'in') continue;
      final ms = (m['createdAtMs'] as int?) ?? 0;
      if (ms > newest) newest = ms;
    }
    if (newest == _lastSeenMessageMs) return;
    _lastSeenMessageMs = newest;
    PlayerCache.saveLastSeenMessageMs(newest);
    notifyListeners();
  }

  /// Detecta missatges nous respecte als que ja coneixíem. El primer estat
  /// després de (re)connectar només s'apunta, sense avisos, per no omplir
  /// la pantalla de notificacions antigues.
  void _trackIncomingMessages(Map<String, Object?> state) {
    final list = state['inbox'] as List?;
    if (list == null) return;
    for (final raw in list) {
      final message = Map<String, Object?>.from(raw as Map);
      final id = message['id'] as String?;
      if (id == null) continue;
      final isNew = _knownMessageIds.add(id);
      if (isNew &&
          _inboxInitialized &&
          message['direction'] == 'in' &&
          !_incomingController.isClosed) {
        _incomingController.add(message);
      }
    }
    _inboxInitialized = true;
  }

  void _onJoined(String playerId, String sessionId) {
    _playerId = playerId;
    notifyListeners();
  }

  void _onState(Map<String, Object?> state) {
    _lastState = state;
    _trackIncomingMessages(state);
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
    if (!connected) _inboxInitialized = false;
    notifyListeners();
  }

  void leaveSession() {
    _client.disconnect();
    PlayerCache.clearConnection();
    _playerId = null;
    _lastState = null;
    _connected = false;
    _knownMessageIds.clear();
    _inboxInitialized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _incomingController.close();
    _client.disconnect();
    super.dispose();
  }
}
