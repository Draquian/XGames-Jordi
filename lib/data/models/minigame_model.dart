import 'dart:convert';

enum MinigameStatus { pending, inProgress, finished }

MinigameStatus minigameStatusFromString(String value) {
  return MinigameStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => MinigameStatus.pending,
  );
}

/// Punts que corresponen a una posició concreta (1r, 2n...). Els punts són
/// sempre enters i poden ser positius, negatius o zero.
class ScoringRule {
  final int position;
  final int points;

  const ScoringRule({required this.position, required this.points});

  Map<String, Object?> toMap() => {'position': position, 'points': points};

  factory ScoringRule.fromMap(Map<String, Object?> map) {
    return ScoringRule(
      position: map['position'] as int,
      points: map['points'] as int,
    );
  }
}

/// Un minijoc dins d'una sessió: nom, normes i el seu propi sistema de
/// puntuació (independent del de la resta de minijocs).
class MinigameModel {
  final String id;
  final String sessionId;
  final String name;
  final String description;
  final String rules;
  final List<ScoringRule> scoring;
  final MinigameStatus status;
  final int orderIndex;
  final DateTime createdAt;

  const MinigameModel({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.description,
    required this.rules,
    required this.scoring,
    required this.status,
    required this.orderIndex,
    required this.createdAt,
  });

  MinigameModel copyWith({
    String? name,
    String? description,
    String? rules,
    List<ScoringRule>? scoring,
    MinigameStatus? status,
  }) {
    return MinigameModel(
      id: id,
      sessionId: sessionId,
      name: name ?? this.name,
      description: description ?? this.description,
      rules: rules ?? this.rules,
      scoring: scoring ?? this.scoring,
      status: status ?? this.status,
      orderIndex: orderIndex,
      createdAt: createdAt,
    );
  }

  /// Punts que li tocarien a una posició segons les regles d'aquest
  /// minijoc. Si la posició no té regla pròpia (per exemple, un minijoc
  /// amb només 1r/2n/3r i un jugador que ha quedat 5è), es fa servir 0.
  int pointsForPosition(int position) {
    for (final rule in scoring) {
      if (rule.position == position) return rule.points;
    }
    return 0;
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'name': name,
      'description': description,
      'rules': rules,
      'scoring_json': jsonEncode(scoring.map((s) => s.toMap()).toList()),
      'status': status.name,
      'order_index': orderIndex,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory MinigameModel.fromMap(Map<String, Object?> map) {
    final rawList = jsonDecode(map['scoring_json'] as String) as List;
    return MinigameModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      rules: map['rules'] as String,
      scoring: rawList
          .map((e) => ScoringRule.fromMap(Map<String, Object?>.from(e as Map)))
          .toList(),
      status: minigameStatusFromString(map['status'] as String),
      orderIndex: map['order_index'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// El que veu un jugador mentre el minijoc està actiu: res de puntuació,
  /// només la informació que necessita per jugar.
  Map<String, Object?> toPublicJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'rules': rules,
      'status': status.name,
      'orderIndex': orderIndex,
    };
  }
}
