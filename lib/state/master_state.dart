import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/local/master_database.dart';
import '../data/models/minigame_model.dart';
import '../data/models/player_model.dart';
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
  );

  SessionModel? _session;
  List<PlayerModel> _players = [];
  List<MinigameModel> _minigames = [];
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

  @override
  void dispose() {
    _server.stop();
    WakelockPlus.disable();
    super.dispose();
  }
}
