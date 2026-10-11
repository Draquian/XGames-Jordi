/// El resultat d'UN jugador en UN minijoc: la posició que ha quedat i els
/// punts que se li han assignat (poden haver estat corregits a mà pel
/// màster, per això es guarda `editedManually`).
class MinigameResultModel {
  final String id;
  final String minigameId;
  final String playerId;
  final int position;
  final int points;
  final String? notes;
  final DateTime recordedAt;
  final bool editedManually;

  const MinigameResultModel({
    required this.id,
    required this.minigameId,
    required this.playerId,
    required this.position,
    required this.points,
    this.notes,
    required this.recordedAt,
    this.editedManually = false,
  });

  MinigameResultModel copyWith({
    int? position,
    int? points,
    String? notes,
    bool? editedManually,
  }) {
    return MinigameResultModel(
      id: id,
      minigameId: minigameId,
      playerId: playerId,
      position: position ?? this.position,
      points: points ?? this.points,
      notes: notes ?? this.notes,
      recordedAt: recordedAt,
      editedManually: editedManually ?? this.editedManually,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'minigame_id': minigameId,
      'player_id': playerId,
      'position': position,
      'points': points,
      'notes': notes,
      'recorded_at': recordedAt.millisecondsSinceEpoch,
      'edited_manually': editedManually ? 1 : 0,
    };
  }

  factory MinigameResultModel.fromMap(Map<String, Object?> map) {
    return MinigameResultModel(
      id: map['id'] as String,
      minigameId: map['minigame_id'] as String,
      playerId: map['player_id'] as String,
      position: map['position'] as int,
      points: map['points'] as int,
      notes: map['notes'] as String?,
      recordedAt:
          DateTime.fromMillisecondsSinceEpoch(map['recorded_at'] as int),
      editedManually: (map['edited_manually'] as int? ?? 0) == 1,
    );
  }
}
