import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/local/master_database.dart';
import '../data/models/minigame_model.dart';
import '../data/models/minigame_result_model.dart';
import '../data/models/player_model.dart';
import '../data/models/point_adjustment_model.dart';
import '../data/models/session_model.dart';
import '../network/connection_info.dart';
import '../network/master_server.dart';

/// Estat central del dispositiu del MÀSTER. La UI (pantalles) només llegeix
/// d'aquí i crida les seves accions; mai toca la base de dades ni la xarxa
/// directament.
class MasterState extends ChangeNotifier {
  static const _uuid = Uuid();
  static const _joinCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  late final MasterServer _server = MasterServer(
    onPlayersUpdated: _onPlayersUpdated,
    buildStateForPlayer: _buildStateForPlayer,
  );

  SessionModel? _session;
  List<PlayerModel> _players = [];
  List<MinigameModel> _minigames = [];
  Map<String, int> _totalPoints = {};
  String? _localIp;
  bool _isStarting = false;

  /// `no_wifi` si el dispositiu no té cap xarxa WiFi activa (cal guiar el
  /// màster a activar el seu punt d'accés personal), `null` si no hi ha
  /// error.
  String? _startError;

  SessionModel? get session => _session;
  List<PlayerModel> get players => List.unmodifiable(_players);
  List<MinigameModel> get minigames => List.unmodifiable(_minigames);
  bool get isStarting => _isStarting;
  String? get startError => _startError;
  String? get localIp => _localIp;
  bool get hasActiveSession => _session != null;

  int totalPointsFor(String playerId) => _totalPoints[playerId] ?? 0;

  /// Jugadors ordenats de més a menys punts (la classificació general).
  List<PlayerModel> get rankedPlayers {
    final list = [..._players];
    list.sort(
      (a, b) => totalPointsFor(b.id).compareTo(totalPointsFor(a.id)),
    );
    return list;
  }

  /// La classificació final (nom + punts), sense els jugadors expulsats:
  /// és exactament el que veurà tothom al podi quan la partida acabi.
  List<Map<String, Object?>> get finalStandings => _computeFinalStandings();

  List<Map<String, Object?>> _computeFinalStandings() {
    final list = _players.where((p) => p.status != PlayerStatus.kicked).toList()
      ..sort((a, b) {
        final byPoints = totalPointsFor(b.id).compareTo(totalPointsFor(a.id));
        if (byPoints != 0) return byPoints;
        return a.name.compareTo(b.name);
      });
    return list
        .map((p) => {'name': p.name, 'totalPoints': totalPointsFor(p.id)})
        .toList();
  }

  ConnectionInfo? get connectionInfo {
    final session = _session;
    final ip = _localIp;
    if (session == null || ip == null) return null;
    return ConnectionInfo(
      sessionId: session.id,
      sessionName: session.name,
      host: ip,
      port: session.port,
      joinCode: session.joinCode,
    );
  }

  void _onPlayersUpdated(List<PlayerModel> players) {
    _players = players;
    notifyListeners();
  }

  /// Construeix el missatge que rebrà EXACTAMENT aquest jugador: les
  /// seves pròpies dades completes (nom, punts totals, historial) i,
  /// de la resta, només el nom i l'estat de connexió.
  Future<Map<String, Object?>> _buildStateForPlayer(PlayerModel player) async {
    final session = _session!;
    final totalPoints = await MasterDatabase.instance.getTotalPoints(player.id);
    final history = await _buildHistoryEntries(player.id);
    final roster = _players
        .where((p) => p.status != PlayerStatus.kicked)
        .map((p) => p.toRosterJson())
        .toList();
    final finalStandings = session.status == SessionStatus.finished
        ? _computeFinalStandings()
        : const <Object?>[];
    return {
      'session': session.toPublicJson(),
      'minigames': _minigames.map((m) => m.toPublicJson()).toList(),
      'me': {
        'playerId': player.id,
        'name': player.name,
        'totalPoints': totalPoints,
        'history': history,
        'status': player.status.name,
      },
      'players': roster,
      'finalStandings': finalStandings,
    };
  }

  /// L'historial complet d'un jugador, barrejant resultats de minijocs i
  /// ajustaments manuals, ordenat cronològicament. El fa servir tant el
  /// missatge que rep cada jugador com la pantalla del màster.
  Future<List<Map<String, Object?>>> _buildHistoryEntries(
    String playerId,
  ) async {
    final db = MasterDatabase.instance;
    final results = await db.getResultsForPlayer(playerId);
    final adjustments = await db.getAdjustmentsForPlayer(playerId);
    final entries = <Map<String, Object?>>[];

    for (final r in results) {
      MinigameModel? minigame;
      for (final m in _minigames) {
        if (m.id == r.minigameId) {
          minigame = m;
          break;
        }
      }
      entries.add({
        'type': 'result',
        'label': minigame?.name ?? '???',
        'position': r.position,
        'points': r.points,
        'timestampMs': r.recordedAt.millisecondsSinceEpoch,
      });
    }
    for (final a in adjustments) {
      entries.add({
        'type': 'adjustment',
        'label': a.reason,
        'position': null,
        'points': a.delta,
        'timestampMs': a.createdAt.millisecondsSinceEpoch,
      });
    }
    entries.sort((x, y) =>
        (x['timestampMs'] as int).compareTo(y['timestampMs'] as int));
    return entries;
  }

  /// Versió pública de `_buildHistoryEntries`, per a la pantalla del
  /// màster que mostra l'historial complet d'un jugador.
  Future<List<Map<String, Object?>>> loadHistoryForPlayer(String playerId) =>
      _buildHistoryEntries(playerId);

  Future<void> _refreshTotals() async {
    final db = MasterDatabase.instance;
    final map = <String, int>{};
    for (final p in _players) {
      map[p.id] = await db.getTotalPoints(p.id);
    }
    _totalPoints = map;
  }

  /// Afegeix (o resta) punts a un jugador fora del flux normal d'un
  /// minijoc: una correcció puntual, una penalització, un extra... El
  /// jugador veurà el motiu al seu propi historial.
  Future<void> addPointAdjustment({
    required String playerId,
    required int delta,
    required String reason,
  }) async {
    await MasterDatabase.instance.insertAdjustment(PointAdjustmentModel(
      id: _uuid.v4(),
      playerId: playerId,
      delta: delta,
      reason: reason.trim(),
      createdAt: DateTime.now(),
    ));
    await _refreshTotals();
    await _server.broadcastNow();
    notifyListeners();
  }

  /// En obrir l'app, comprova si hi havia una partida sense acabar i la
  /// recupera exactament amb el mateix identificador i codi de sessió.
  Future<bool> tryResumeSession() async {
    final existing = await MasterDatabase.instance.getResumableSession();
    if (existing == null) return false;
    _isStarting = true;
    notifyListeners();
    _localIp = await getLocalWifiIp();
    final assignedPort = await _server.resume(existing);
    final resumed = SessionModel(
      id: existing.id,
      name: existing.name,
      status: existing.status,
      createdAt: existing.createdAt,
      joinCode: existing.joinCode,
      port: assignedPort,
      currentMinigameId: existing.currentMinigameId,
      lockedForNewPlayers: existing.lockedForNewPlayers,
    );
    _session = resumed;
    await MasterDatabase.instance.upsertSession(resumed);
    _players = _server.players;
    _minigames = await MasterDatabase.instance.getMinigamesForSession(resumed.id);
    await _refreshTotals();
    _isStarting = false;
    if (_localIp != null) await WakelockPlus.enable();
    notifyListeners();
    return true;
  }

  /// Crea una sessió nova des de zero: genera codi, arrenca el servidor
  /// local i el desa tot de seguida.
  Future<bool> createSession(String name) async {
    _isStarting = true;
    _startError = null;
    notifyListeners();

    final ip = await getLocalWifiIp();
    if (ip == null) {
      _startError = 'no_wifi';
      _isStarting = false;
      notifyListeners();
      return false;
    }
    _localIp = ip;

    var session = SessionModel(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Navidad de Jordi' : name.trim(),
      status: SessionStatus.active,
      createdAt: DateTime.now(),
      joinCode: _generateJoinCode(),
      port: 0,
    );
    final assignedPort = await _server.start(session);
    session = SessionModel(
      id: session.id,
      name: session.name,
      status: session.status,
      createdAt: session.createdAt,
      joinCode: session.joinCode,
      port: assignedPort,
    );
    _session = session;
    await MasterDatabase.instance.upsertSession(session);
    _players = _server.players;
    _minigames = [];
    _totalPoints = {};
    _isStarting = false;
    await WakelockPlus.enable();
    notifyListeners();
    return true;
  }

  String _generateJoinCode() {
    final rand = Random.secure();
    return List.generate(
      6,
      (_) => _joinCodeChars[rand.nextInt(_joinCodeChars.length)],
    ).join();
  }

  Future<void> refreshLocalIp() async {
    _localIp = await getLocalWifiIp();
    notifyListeners();
  }

  Future<void> kickPlayer(String playerId) => _server.kickPlayer(playerId);

  /// Crea un minijoc nou per a la sessió actual, al final de la llista.
  Future<void> createMinigame({
    required String name,
    required String description,
    required String rules,
    required List<ScoringRule> scoring,
  }) async {
    final session = _session;
    if (session == null) return;
    final minigame = MinigameModel(
      id: _uuid.v4(),
      sessionId: session.id,
      name: name.trim(),
      description: description.trim(),
      rules: rules.trim(),
      scoring: scoring,
      status: MinigameStatus.pending,
      orderIndex: _minigames.length,
      createdAt: DateTime.now(),
    );
    await MasterDatabase.instance.upsertMinigame(minigame);
    _minigames = [..._minigames, minigame];
    notifyListeners();
  }

  /// Edita un minijoc ja existent (nom, descripció, normes o puntuació).
  /// L'historial de resultats ja jugats amb les regles anteriors NO es
  /// recalcula: només canvia la definició de cara al que quedi per jugar.
  Future<void> updateMinigame(
    String minigameId, {
    required String name,
    required String description,
    required String rules,
    required List<ScoringRule> scoring,
  }) async {
    final idx = _minigames.indexWhere((m) => m.id == minigameId);
    if (idx == -1) return;
    final updated = _minigames[idx].copyWith(
      name: name.trim(),
      description: description.trim(),
      rules: rules.trim(),
      scoring: scoring,
    );
    await MasterDatabase.instance.upsertMinigame(updated);
    _minigames = [..._minigames]..[idx] = updated;
    notifyListeners();
  }

  /// Comença un minijoc: els jugadors ho veuran a l'instant a les seves
  /// pantalles. Només un minijoc pot estar en curs alhora.
  Future<bool> startMinigame(String minigameId) async {
    final session = _session;
    if (session == null || session.currentMinigameId != null) return false;
    final idx = _minigames.indexWhere((m) => m.id == minigameId);
    if (idx == -1) return false;

    final updatedMinigame =
        _minigames[idx].copyWith(status: MinigameStatus.inProgress);
    await MasterDatabase.instance.upsertMinigame(updatedMinigame);
    _minigames = [..._minigames]..[idx] = updatedMinigame;

    final updatedSession = session.copyWith(currentMinigameId: minigameId);
    _session = updatedSession;
    _server.updateSession(updatedSession);
    await MasterDatabase.instance.upsertSession(updatedSession);

    await _server.broadcastNow();
    notifyListeners();
    return true;
  }

  /// Posicions ja desades d'un minijoc (per preomplir el formulari de
  /// resultats si el màster hi torna a entrar per corregir-les).
  Future<Map<String, int>> loadPositionsForMinigame(String minigameId) async {
    final results =
        await MasterDatabase.instance.getResultsForMinigame(minigameId);
    return {for (final r in results) r.playerId: r.position};
  }

  /// Finalitza un minijoc: desa la posició de cada jugador que hi ha
  /// participat (`positionsByPlayerId`), calcula els punts segons les
  /// regles del minijoc (incloent la regla especial d'"últim/a") i ho
  /// retransmet a tothom. També serveix per CORREGIR els resultats d'un
  /// minijoc ja finalitzat: torna a calcular-ho tot des de zero.
  Future<void> finishMinigame({
    required String minigameId,
    required Map<String, int> positionsByPlayerId,
  }) async {
    final idx = _minigames.indexWhere((m) => m.id == minigameId);
    if (idx == -1) return;
    final minigame = _minigames[idx];
    final isCorrection = minigame.status == MinigameStatus.finished;
    final db = MasterDatabase.instance;

    await db.deleteResultsForMinigame(minigameId);
    if (positionsByPlayerId.isNotEmpty) {
      final worstPosition =
          positionsByPlayerId.values.reduce((a, b) => a > b ? a : b);
      for (final entry in positionsByPlayerId.entries) {
        final points = minigame.pointsFor(
          position: entry.value,
          worstPosition: worstPosition,
        );
        await db.upsertResult(MinigameResultModel(
          id: _uuid.v4(),
          minigameId: minigameId,
          playerId: entry.key,
          position: entry.value,
          points: points,
          recordedAt: DateTime.now(),
          editedManually: isCorrection,
        ));
      }
    }

    final updatedMinigame = minigame.copyWith(status: MinigameStatus.finished);
    await db.upsertMinigame(updatedMinigame);
    _minigames = [..._minigames]..[idx] = updatedMinigame;
    await _refreshTotals();

    final session = _session;
    if (session != null && session.currentMinigameId == minigameId) {
      final updatedSession = session.copyWith(clearCurrentMinigameId: true);
      _session = updatedSession;
      _server.updateSession(updatedSession);
      await db.upsertSession(updatedSession);
    }

    await _server.broadcastNow();
    notifyListeners();
  }

  /// Tanca (o torna a obrir) la sessió a noves incorporacions. Els
  /// jugadors que ja hi eren sempre poden reconnectar-se, tanquis o no.
  Future<void> setLockedForNewPlayers(bool locked) async {
    final current = _session;
    if (current == null) return;
    final updated = current.copyWith(lockedForNewPlayers: locked);
    _session = updated;
    _server.updateSession(updated);
    await MasterDatabase.instance.upsertSession(updated);
    notifyListeners();
  }

  /// Finalitza la partida: tothom veurà el podi final a l'instant. No es
  /// pot finalitzar mentre hi hagi un minijoc en curs (cal acabar-lo
  /// primer). En finalitzar, la sessió també es tanca a noves
  /// incorporacions.
  Future<bool> endSession() async {
    final session = _session;
    if (session == null || session.currentMinigameId != null) return false;
    await _refreshTotals();
    final updated = session.copyWith(
      status: SessionStatus.finished,
      lockedForNewPlayers: true,
    );
    _session = updated;
    _server.updateSession(updated);
    await MasterDatabase.instance.upsertSession(updated);
    await _server.broadcastNow();
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _server.stop();
    WakelockPlus.disable();
    super.dispose();
  }
}
