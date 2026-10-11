/// Un canvi de punts que el màster fa a mà, fora del flux normal d'un
/// minijoc (per exemple, una penalització puntual o una correcció).
class PointAdjustmentModel {
  final String id;
  final String playerId;
  final int delta;
  final String reason;
  final DateTime createdAt;
  final String? relatedMinigameId;

  const PointAdjustmentModel({
    required this.id,
    required this.playerId,
    required this.delta,
    required this.reason,
    required this.createdAt,
    this.relatedMinigameId,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'player_id': playerId,
      'delta': delta,
      'reason': reason,
      'created_at': createdAt.millisecondsSinceEpoch,
      'related_minigame_id': relatedMinigameId,
    };
  }

  factory PointAdjustmentModel.fromMap(Map<String, Object?> map) {
    return PointAdjustmentModel(
      id: map['id'] as String,
      playerId: map['player_id'] as String,
      delta: map['delta'] as int,
      reason: map['reason'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      relatedMinigameId: map['related_minigame_id'] as String?,
    );
  }
}
