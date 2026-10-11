enum PlayerStatus { connected, disconnected, kicked }

PlayerStatus playerStatusFromString(String value) {
  return PlayerStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => PlayerStatus.disconnected,
  );
}

/// Un jugador dins d'una sessió. `deviceId` és l'identificador persistent
/// que genera el dispositiu del jugador la primera vegada que s'uneix, i que
/// permet reconnectar-lo automàticament sense duplicar-lo.
class PlayerModel {
  final String id;
  final String sessionId;
  final String name;
  final PlayerStatus status;
  final String deviceId;
  final DateTime joinedAt;

  const PlayerModel({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.status,
    required this.deviceId,
    required this.joinedAt,
  });

  PlayerModel copyWith({
    String? name,
    PlayerStatus? status,
    String? deviceId,
  }) {
    return PlayerModel(
      id: id,
      sessionId: sessionId,
      name: name ?? this.name,
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      joinedAt: joinedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'name': name,
      'status': status.name,
      'device_id': deviceId,
      'joined_at': joinedAt.millisecondsSinceEpoch,
    };
  }

  factory PlayerModel.fromMap(Map<String, Object?> map) {
    return PlayerModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      name: map['name'] as String,
      status: playerStatusFromString(map['status'] as String),
      deviceId: map['device_id'] as String,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joined_at'] as int),
    );
  }

  /// Nom + estat únicament: és el que veuen ELS ALTRES jugadors d'aquest
  /// jugador (mai els seus punts, per privacitat).
  Map<String, Object?> toRosterJson() {
    return {'id': id, 'name': name, 'status': status.name};
  }
}
