/// Estat general d'una sessió de partida.
enum SessionStatus { setup, active, finished }

SessionStatus sessionStatusFromString(String value) {
  return SessionStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => SessionStatus.setup,
  );
}

/// Representa una partida completa: el "esdeveniment" que el màster crea
/// i que agrupa jugadors, minijocs, resultats i historial.
class SessionModel {
  final String id;
  final String name;
  final SessionStatus status;
  final DateTime createdAt;

  /// Codi curt (i contingut del QR) que fan servir els jugadors per unir-se.
  final String joinCode;

  /// Port TCP on escolta el servidor local del màster.
  final int port;

  /// Minijoc que està actualment en curs (null si cap).
  final String? currentMinigameId;

  /// Si està tancada, no s'accepten noves incorporacions encara que algú
  /// tingui el codi/QR.
  final bool lockedForNewPlayers;

  const SessionModel({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.joinCode,
    required this.port,
    this.currentMinigameId,
    this.lockedForNewPlayers = false,
  });

  SessionModel copyWith({
    String? name,
    SessionStatus? status,
    String? currentMinigameId,
    bool clearCurrentMinigameId = false,
    bool? lockedForNewPlayers,
  }) {
    return SessionModel(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAt: createdAt,
      joinCode: joinCode,
      port: port,
      currentMinigameId: clearCurrentMinigameId
          ? null
          : (currentMinigameId ?? this.currentMinigameId),
      lockedForNewPlayers: lockedForNewPlayers ?? this.lockedForNewPlayers,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status.name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'join_code': joinCode,
      'port': port,
      'current_minigame_id': currentMinigameId,
      'locked_for_new_players': lockedForNewPlayers ? 1 : 0,
    };
  }

  factory SessionModel.fromMap(Map<String, Object?> map) {
    return SessionModel(
      id: map['id'] as String,
      name: map['name'] as String,
      status: sessionStatusFromString(map['status'] as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      joinCode: map['join_code'] as String,
      port: map['port'] as int,
      currentMinigameId: map['current_minigame_id'] as String?,
      lockedForNewPlayers: (map['locked_for_new_players'] as int? ?? 0) == 1,
    );
  }

  /// Versió pública i mínima que s'envia als jugadors: cap dada sensible.
  Map<String, Object?> toPublicJson() {
    return {
      'id': id,
      'name': name,
      'status': status.name,
      'currentMinigameId': currentMinigameId,
    };
  }
}
