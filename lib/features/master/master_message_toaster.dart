import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/master_state.dart';
import 'master_messages_screen.dart';

/// Envolta la pantalla principal del màster i mostra un avís quan un
/// jugador li envia un missatge mentre l'app és oberta.
class MasterMessageToaster extends StatefulWidget {
  const MasterMessageToaster({super.key, required this.child});

  final Widget child;

  @override
  State<MasterMessageToaster> createState() => _MasterMessageToasterState();
}

class _MasterMessageToasterState extends State<MasterMessageToaster> {
  StreamSubscription<Map<String, Object?>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = context.read<MasterState>().incomingMessages.listen(_onIncoming);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MasterMessagesScreen()),
    );
  }

  void _onIncoming(Map<String, Object?> message) {
    if (!mounted) return;
    final from = message['fromName'] as String? ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Missatge de $from"),
        action: SnackBarAction(label: "Veure", onPressed: _open),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
