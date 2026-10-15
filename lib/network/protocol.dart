import 'dart:convert';

/// Tots els missatges viatgen com a JSON amb un camp `type`. Es defineixen
/// aquí els tipus per evitar cadenes de text soltes escampades pel codi.
///
/// Missatges JUGADOR -> MÀSTER
class ClientMsgType {
  static const join = 'join'; // {deviceId, name}
  static const leave = 'leave'; // {}
  static const sendMessage = 'send_message'; // {toPlayerId, body, points}
}

/// Missatges MÀSTER -> JUGADOR
class ServerMsgType {
  static const joinOk = 'join_ok'; // {playerId, sessionId}
  static const joinRejected = 'join_rejected'; // {reason}
  static const state = 'state'; // {session, minigames, me, players}
  static const kicked = 'kicked'; // {}
  static const sessionEnded = 'session_ended'; // {standings}
  static const sendResult = 'send_result'; // {ok, reason}
}

/// Codifica un missatge amb el seu tipus per enviar-lo pel WebSocket.
String encodeMessage(String type, Map<String, Object?> payload) {
  return jsonEncode({'type': type, ...payload});
}

/// Descodifica un missatge rebut. Retorna sempre un mapa amb com a mínim
/// la clau `type`; si el text no és JSON vàlid, `type` queda buit.
Map<String, Object?> decodeMessage(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
  } catch (_) {
    // Missatge mal format: s'ignora silenciosament al punt de crida.
  }
  return {'type': ''};
}
