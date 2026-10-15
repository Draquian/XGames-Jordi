import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'connection_info.dart';
import 'protocol.dart';

/// Connexió del dispositiu d'un JUGADOR cap al servidor del màster.
/// Si es perd la connexió (el màster tanca l'app, es surt de l'abast del
/// WiFi...), ho reintenta automàticament cada pocs segons amb les mateixes
/// dades, sense que calgui tornar a escanejar el QR.
class PlayerClient {
  PlayerClient({
    required this.onJoined,
    required this.onState,
    required this.onKicked,
    required this.onConnectionChanged,
    required this.onJoinRejected,
    required this.onSendResult,
  });

  final void Function(String playerId, String sessionId) onJoined;
  final void Function(Map<String, Object?> state) onState;
  final void Function() onKicked;
  final void Function(bool connected) onConnectionChanged;
  final void Function(String reason) onJoinRejected;
  final void Function(bool ok, String? reason) onSendResult;

  static const _retryDelay = Duration(seconds: 3);

  WebSocketChannel? _channel;
  Timer? _retryTimer;
  ConnectionInfo? _connectionInfo;
  String? _deviceId;
  String? _playerName;
  bool _stoppedByUser = false;

  bool get isConnected => _channel != null;

  Future<void> connect({
    required ConnectionInfo connectionInfo,
    required String deviceId,
    required String playerName,
  }) async {
    _connectionInfo = connectionInfo;
    _deviceId = deviceId;
    _playerName = playerName;
    _stoppedByUser = false;
    _retryTimer?.cancel();
    await _attemptConnect();
  }

  Future<void> _attemptConnect() async {
    final info = _connectionInfo;
    if (info == null || _stoppedByUser) return;
    try {
      final uri = Uri.parse('ws://${info.host}:${info.port}/ws');
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
      onConnectionChanged(true);
      channel.sink.add(encodeMessage(ClientMsgType.join, {
        'deviceId': _deviceId,
        'name': _playerName,
        'joinCode': info.joinCode,
      }));
      channel.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _handleMessage(dynamic raw) {
    final msg = decodeMessage(raw as String);
    switch (msg['type']) {
      case ServerMsgType.joinOk:
        onJoined(msg['playerId'] as String, msg['sessionId'] as String);
        break;
      case ServerMsgType.state:
        onState(msg);
        break;
      case ServerMsgType.kicked:
        _stoppedByUser = true;
        onKicked();
        _closeChannelOnly();
        break;
      case ServerMsgType.joinRejected:
        _stoppedByUser = true;
        onJoinRejected(msg['reason'] as String? ?? 'unknown');
        _closeChannelOnly();
        break;
      case ServerMsgType.sendResult:
        onSendResult(msg['ok'] == true, msg['reason'] as String?);
        break;
    }
  }

  void _handleDisconnect() {
    _channel = null;
    onConnectionChanged(false);
    if (!_stoppedByUser) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, _attemptConnect);
  }

  void _closeChannelOnly() {
    _channel?.sink.close();
    _channel = null;
  }

  /// Demana al màster enviar un missatge privat (i, si `points` > 0, una
  /// transferència de punts). Retorna `false` si ara mateix no hi ha
  /// connexió; la resposta del màster arriba per `onSendResult`.
  bool sendMessage({
    required String toPlayerId,
    required String body,
    required int points,
  }) {
    final channel = _channel;
    if (channel == null) return false;
    channel.sink.add(encodeMessage(ClientMsgType.sendMessage, {
      'toPlayerId': toPlayerId,
      'body': body,
      'points': points,
    }));
    return true;
  }

  /// L'usuari surt voluntàriament (per exemple, torna a la pantalla
  /// d'inici): a diferència d'una desconnexió accidental, aquí NO es
  /// reintenta.
  void disconnect() {
    _stoppedByUser = true;
    _retryTimer?.cancel();
    _closeChannelOnly();
  }
}
