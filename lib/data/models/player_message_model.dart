/// Identificador especial que fa servir un jugador per escriure al màster
/// (el màster no és un jugador, així que no té identificador propi).
const String masterRecipientId = 'master';

/// Un missatge privat entre dos jugadors, amb una transferència de punts
/// opcional (`points` > 0). Només el veuen el remitent i el destinatari.
class PlayerMessageModel {
  final String id;
  final String sessionId;
  final String fromPlayerId;
  final String toPlayerId;
  final String body;

  /// Punts que el remitent cedeix al destinatari (0 si és només un missatge).
  final int points;
  final DateTime createdAt;

  const PlayerMessageModel({
    required this.id,
    required this.sessionId,
    required this.fromPlayerId,
    required this.toPlayerId,
    required this.body,
    required this.points,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'from_player_id': fromPlayerId,
      'to_player_id': toPlayerId,
      'body': body,
      'points': points,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PlayerMessageModel.fromMap(Map<String, Object?> map) {
    return PlayerMessageModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      fromPlayerId: map['from_player_id'] as String,
      toPlayerId: map['to_player_id'] as String,
      body: map['body'] as String,
      points: map['points'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
