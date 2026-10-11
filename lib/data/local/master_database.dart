import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/minigame_model.dart';
import '../models/minigame_result_model.dart';
import '../models/player_model.dart';
import '../models/point_adjustment_model.dart';
import '../models/session_model.dart';

/// Accés a la base de dades local del MÀSTER. Cada acció de partida es
/// desa immediatament com una transacció: si l'aplicació es tanca o el
/// mòbil es reinicia, res es perd i la sessió es pot recuperar tal qual.
///
/// Aquesta base de dades NOMÉS existeix al dispositiu del màster. Els
/// jugadors tenen la seva pròpia caché, molt més petita (vegeu
/// `player_cache.dart`).
class MasterDatabase {
  MasterDatabase._();
  static final MasterDatabase instance = MasterDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'navidad_de_jordi.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            join_code TEXT NOT NULL,
            port INTEGER NOT NULL,
            current_minigame_id TEXT,
            locked_for_new_players INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE players (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            name TEXT NOT NULL,
            status TEXT NOT NULL,
            device_id TEXT NOT NULL,
            joined_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE minigames (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            rules TEXT NOT NULL,
            scoring_json TEXT NOT NULL,
            status TEXT NOT NULL,
            order_index INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE minigame_results (
            id TEXT PRIMARY KEY,
            minigame_id TEXT NOT NULL,
            player_id TEXT NOT NULL,
            position INTEGER NOT NULL,
            points INTEGER NOT NULL,
            notes TEXT,
            recorded_at INTEGER NOT NULL,
            edited_manually INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE point_adjustments (
            id TEXT PRIMARY KEY,
            player_id TEXT NOT NULL,
            delta INTEGER NOT NULL,
            reason TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            related_minigame_id TEXT
          )
        ''');
      },
    );
  }

  // ---------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------

  Future<void> upsertSession(SessionModel session) async {
    final db = await database;
    await db.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// La sessió no finalitzada més recent, si n'hi ha. Es fa servir en
  /// arrencar l'app per oferir "continuar la partida en curs".
  Future<SessionModel?> getResumableSession() async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'status != ?',
      whereArgs: [SessionStatus.finished.name],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SessionModel.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------
  // Jugadors
  // ---------------------------------------------------------------------

  Future<void> upsertPlayer(PlayerModel player) async {
    final db = await database;
    await db.insert(
      'players',
      player.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PlayerModel>> getPlayersForSession(String sessionId) async {
    final db = await database;
    final rows = await db.query(
      'players',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'joined_at ASC',
    );
    return rows.map(PlayerModel.fromMap).toList();
  }

  /// Busca un jugador ja existent per `deviceId` dins d'una sessió. És la
  /// clau de la reconnexió automàtica: si coincideix, és el mateix
  /// jugador d'abans i conserva els seus punts i historial.
  Future<PlayerModel?> findPlayerByDeviceId(
    String sessionId,
    String deviceId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'players',
      where: 'session_id = ? AND device_id = ?',
      whereArgs: [sessionId, deviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PlayerModel.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------
  // Minijocs, resultats i ajustaments (base preparada per a properes fases)
  // ---------------------------------------------------------------------

  Future<void> upsertMinigame(MinigameModel minigame) async {
    final db = await database;
    await db.insert(
      'minigames',
      minigame.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MinigameModel>> getMinigamesForSession(String sessionId) async {
    final db = await database;
    final rows = await db.query(
      'minigames',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'order_index ASC',
    );
    return rows.map(MinigameModel.fromMap).toList();
  }

  Future<void> upsertResult(MinigameResultModel result) async {
    final db = await database;
    await db.insert(
      'minigame_results',
      result.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MinigameResultModel>> getResultsForPlayer(
    String playerId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'minigame_results',
      where: 'player_id = ?',
      whereArgs: [playerId],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(MinigameResultModel.fromMap).toList();
  }

  Future<void> insertAdjustment(PointAdjustmentModel adjustment) async {
    final db = await database;
    await db.insert('point_adjustments', adjustment.toMap());
  }

  Future<List<PointAdjustmentModel>> getAdjustmentsForPlayer(
    String playerId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'point_adjustments',
      where: 'player_id = ?',
      whereArgs: [playerId],
      orderBy: 'created_at ASC',
    );
    return rows.map(PointAdjustmentModel.fromMap).toList();
  }

  /// Puntuació total d'un jugador: suma de tots els seus resultats de
  /// minijoc més tots els ajustaments manuals.
  Future<int> getTotalPoints(String playerId) async {
    final results = await getResultsForPlayer(playerId);
    final adjustments = await getAdjustmentsForPlayer(playerId);
    final resultsSum = results.fold<int>(0, (sum, r) => sum + r.points);
    final adjustmentsSum =
        adjustments.fold<int>(0, (sum, a) => sum + a.delta);
    return resultsSum + adjustmentsSum;
  }
}
