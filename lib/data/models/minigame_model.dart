import 'dart:convert';

enum MinigameStatus { pending, inProgress, finished }

MinigameStatus minigameStatusFromString(String value) {
  return MinigameStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => MinigameStatus.pending,
  );
}

/// Tipus d'una regla de puntuació: una posició exacta (1r, 2n...) o la
/// posició "última", sigui quina sigui (útil quan el nombre de jugadors
/// varia d'una partida a l'altra del mateix minijoc).
enum ScoringRuleType { exactPosition, lastPlace }

/// Punts que corresponen a una posició concreta, o a "qui quedi últim".
/// Els punts són sempre enters i poden ser positius, negatius o zero.
class ScoringRule {
  final ScoringRuleType type;

  /// Només té sentit quan `type == exactPosition`.
  final int? position;
  final int points;

  const ScoringRule.exact({required int pos, required this.points})
      : type = ScoringRuleType.exactPosition,
        position = pos;

  const ScoringRule.last({required this.points})
      : type = ScoringRuleType.lastPlace,
        position = null;

  bool get isLastPlace => type == ScoringRuleType.lastPlace;

  Map<String, Object?> toMap() => {
        'type': type.name,
        'position': position,
        'points': points,
      };

  factory ScoringRule.fromMap(Map<String, Object?> map) {
    if (map['type'] == ScoringRuleType.lastPlace.name) {
      return ScoringRule.last(points: map['points'] as int);
    }
    return ScoringRule.exact(
      pos: map['position'] as int,
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

  /// Regla de posició exacta d'aquest minijoc, si n'hi ha cap per a
  /// `position`.
  ScoringRule? ruleForPosition(int position) {
    for (final rule in scoring) {
      if (!rule.isLastPlace && rule.position == position) return rule;
    }
    return null;
  }

  /// La regla especial "últim/a" d'aquest minijoc, si s'ha definit.
  ScoringRule? get lastPlaceRule {
    for (final rule in scoring) {
      if (rule.isLastPlace) return rule;
    }
    return null;
  }

  /// Punts que li tocarien a un jugador que ha quedat a `position`, sabent
  /// quina és la pitjor posició (`worstPosition`) d'aquesta partida
  /// concreta del minijoc. Prioritat: 1) regla de posició exacta, 2) regla
  /// "últim/a" si aquesta posició és la pitjor, 3) zero punts.
  int pointsFor({required int position, required int worstPosition}) {
    final exact = ruleForPosition(position);
    if (exact != null) return exact.points;
    if (position == worstPosition) {
      final last = lastPlaceRule;
      if (last != null) return last.points;
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
