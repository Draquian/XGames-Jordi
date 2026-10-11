import 'dart:convert';

import 'package:network_info_plus/network_info_plus.dart';

/// Tot el que necessita un jugador per connectar-se al servidor del
/// màster. És exactament el que es codifica dins del QR: NO conté cap
/// dada de la partida, només "com arribar-hi".
class ConnectionInfo {
  final String sessionId;
  final String sessionName;
  final String host;
  final int port;
  final String joinCode;

  const ConnectionInfo({
    required this.sessionId,
    required this.sessionName,
    required this.host,
    required this.port,
    required this.joinCode,
  });

  String toQrPayload() => jsonEncode({
        'sessionId': sessionId,
        'sessionName': sessionName,
        'host': host,
        'port': port,
        'joinCode': joinCode,
      });

  /// Retorna `null` si el text escanejat no és un codi vàlid de Navidad de
  /// Jordi (per exemple, si algú escaneja un QR d'una altra app).
  static ConnectionInfo? tryParse(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      if (map['sessionId'] == null ||
          map['host'] == null ||
          map['port'] == null ||
          map['joinCode'] == null) {
        return null;
      }
      return ConnectionInfo(
        sessionId: map['sessionId'] as String,
        sessionName: (map['sessionName'] as String?) ?? 'Partida',
        host: map['host'] as String,
        port: map['port'] as int,
        joinCode: map['joinCode'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Obté la IP local (WiFi) del dispositiu del màster. Si torna `null` vol
/// dir que el dispositiu no està connectat a cap xarxa WiFi: en aquest cas
/// cal guiar el màster perquè activi el seu punt d'accés personal des
/// dels ajustos del sistema abans de tornar-ho a provar.
Future<String?> getLocalWifiIp() async {
  final info = NetworkInfo();
  try {
    return await info.getWifiIP();
  } catch (_) {
    return null;
  }
}
