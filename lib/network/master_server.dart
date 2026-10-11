import 'dart:io';

import 'package:uuid/uuid.dart';

import '../data/local/master_database.dart';
import '../data/models/player_model.dart';
import '../data/models/session_model.dart';
import 'protocol.dart';

/// Servidor local que corre DINS del dispositiu del màster. No fa servir
/// Internet ni cap servei extern: només escolta connexions WebSocket dins
/// de la xarxa WiFi local (router de casa, o el hotspot personal del
/// mateix màster).
///
/// El màster és l'únic que escriu a la base de dades. Els jugadors només
/// poden enviar `join`/`leave`; totes les altres accions (assignar punts,
/// iniciar minijocs...) les fa la UI del màster directament, mai un
/// missatge de xarxa d'un jugador.
class MasterServer {
  MasterServer({required this.onPlayersUpdated});

  /// Es crida cada vegada que la llista de jugadors canvia, perquè la UI
  /// del màster (`MasterState`) es pugui refrescar.
  final void Function(List<PlayerModel> players) onPlayersUpdated;

  static const _uuid = Uuid();

  HttpServer? _httpServer;
  SessionModel? _session;
  List<PlayerModel> _players = [];
  final Map<String, WebSocket> _socketsByPlayerId = {};

  int get port => _httpServer?.port ?? 0;
  List<PlayerModel> get players => List.unmodifiable(_players);

  /// Arrenca el servidor per a una sessió NOVA. Retorna el port real on ha
  /// quedat escoltant (0 vol dir "tria'n un de lliure el sistema").
  Future<int> start(SessionModel session) async {
    _session = session;
    _players = await MasterDatabase.instance.getPlayersForSession(session.id);
    _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _httpServer!.listen(_handleHttpRequest);
    return _httpServer!.port;
  }

  /// Torna a arrencar el servidor per a una sessió que ja existia (per
  /// exemple, en recuperar la partida després de reobrir l'app).
  Future<int> resume(SessionModel session) => start(session);

  Future<void> stop() async {
    for (final socket in _socketsByPlayerId.values) {
      await socket.close();
    }
    _socketsByPlayerId.clear();
    await _httpServer?.close(force: true);
    _httpServer = null;
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      _handleSocket(socket);
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
    }
  }

  void _handleSocket(WebSocket socket) {
    String? boundPlayerId;

    socket.listen(
      (raw) async {
        final msg = decodeMessage(raw as String);
        switch (msg['type']) {
          case ClientMsgType.join:
            final deviceId = msg['deviceId'] as String? ?? '';
            final requestedName =
                (msg['name'] as String? ?? '').trim();
            final providedCode = msg['joinCode'] as String? ?? '';
            if (deviceId.isEmpty || _session == null) return;
            if (providedCode != _session!.joinCode) {
              socket.add(encodeMessage(ServerMsgType.joinRejected, {
                'reason': 'invalid_code',
              }));
              return;
            }
            final existing = await MasterDatabase.instance
                .findPlayerByDeviceId(_session!.id, deviceId);
            if (existing == null && _session!.lockedForNewPlayers) {
              socket.add(encodeMessage(ServerMsgType.joinRejected, {
                'reason': 'locked',
              }));
              return;
            }
            final player = await _resolveOrCreatePlayer(
              deviceId,
              requestedName.isEmpty ? 'Jugador' : requestedName,
              existing,
            );
            boundPlayerId = player.id;
            _socketsByPlayerId[player.id] = socket;
            socket.add(encodeMessage(ServerMsgType.joinOk, {
              'playerId': player.id,
              'sessionId': _session!.id,
            }));
            _broadcastState();
            onPlayersUpdated(_players);
            break;
          case ClientMsgType.leave:
            if (boundPlayerId != null) {
              await _markDisconnected(boundPlayerId!);
            }
            break;
        }
      },
      onDone: () async {
        if (boundPlayerId != null) {
          await _markDisconnected(boundPlayerId!);
        }
      },
      onError: (_) async {
        if (boundPlayerId != null) {
          await _markDisconnected(boundPlayerId!);
        }
      },
      cancelOnError: true,
    );
  }

  /// Actualitza les dades de la sessió (per exemple, en bloquejar noves
  /// incorporacions) sense haver de reiniciar el servidor.
  void updateSession(SessionModel session) {
    _session = session;
  }

  Future<PlayerModel> _resolveOrCreatePlayer(
    String deviceId,
    String name,
    PlayerModel? existing,
  ) async {
    final db = MasterDatabase.instance;
    final player = existing != null
        ? existing.copyWith(status: PlayerStatus.connected)
        : PlayerModel(
            id: _uuid.v4(),
            sessionId: _session!.id,
            name: name,
            status: PlayerStatus.connected,
            deviceId: deviceId,
            joinedAt: DateTime.now(),
          );
    await db.upsertPlayer(player);
    _players = await db.getPlayersForSession(_session!.id);
    return player;
  }

  Future<void> _markDisconnected(String playerId) async {
    _socketsByPlayerId.remove(playerId);
    final idx = _players.indexWhere((p) => p.id == playerId);
    if (idx == -1) return;
    if (_players[idx].status == PlayerStatus.kicked) {
      return; // no reobrim l'estat d'un jugador expulsat
    }
    final updated = _players[idx].copyWith(status: PlayerStatus.disconnected);
    _players[idx] = updated;
    await MasterDatabase.instance.upsertPlayer(updated);
    _broadcastState();
    onPlayersUpdated(_players);
  }

  /// Expulsa un jugador: talla la seva connexió i el marca com a
  /// "expulsat". NO s'esborra del historial ni de la classificació.
  Future<void> kickPlayer(String playerId) async {
    final idx = _players.indexWhere((p) => p.id == playerId);
    if (idx == -1) return;
    final updated = _players[idx].copyWith(status: PlayerStatus.kicked);
    _players[idx] = updated;
    await MasterDatabase.instance.upsertPlayer(updated);
    final socket = _socketsByPlayerId.remove(playerId);
    if (socket != null) {
      socket.add(encodeMessage(ServerMsgType.kicked, const {}));
      await socket.close();
    }
    _broadcastState();
    onPlayersUpdated(_players);
  }

  /// Envia a cada jugador connectat un missatge PERSONALITZAT: les seves
  /// pròpies dades completes, i de la resta només el nom i l'estat (mai
  /// els seus punts), tal com exigeix la privacitat de la classificació.
  void _broadcastState() {
    if (_session == null) return;
    final roster = _players
        .where((p) => p.status != PlayerStatus.kicked)
        .map((p) => p.toRosterJson())
        .toList();
    for (final player in _players) {
      final socket = _socketsByPlayerId[player.id];
      if (socket == null) continue;
      final payload = {
        'session': _session!.toPublicJson(),
        // Fase 1: encara no hi ha minijocs jugables ni puntuació real.
        'minigames': const <Object?>[],
        'me': {
          'playerId': player.id,
          'name': player.name,
          'totalPoints': 0,
          'results': const <Object?>[],
          'status': player.status.name,
        },
        'players': roster,
      };
      socket.add(encodeMessage(ServerMsgType.state, payload));
    }
  }
}
