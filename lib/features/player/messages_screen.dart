import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_state.dart';
import 'compose_message_screen.dart';

/// Missatges privats del jugador: els que ha rebut i els que ha enviat.
/// Només els veu ell (i l'altra persona de cada missatge); ningú més.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  Future<void> _compose() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ComposeMessageScreen()),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enviat.")),
      );
    }
  }

  Widget _buildTile(BuildContext context, Map<String, Object?> message) {
    final isIncoming = message['direction'] == 'in';
    final other = message['otherName'] as String? ?? '';
    final body = message['body'] as String? ?? '';
    final points = message['points'] as int? ?? 0;
    final ms = message['createdAtMs'] as int? ?? 0;
    final time = TimeOfDay.fromDateTime(
      DateTime.fromMillisecondsSinceEpoch(ms),
    ).format(context);

    final lines = <String>[
      if (body.isNotEmpty) body,
      if (points > 0)
        isIncoming ? "Has rebut $points punts" : "Has enviat $points punts",
    ];

    return ListTile(
      leading: Icon(isIncoming ? Icons.call_received : Icons.call_made),
      title: Text(isIncoming ? "De $other" : "Per a $other"),
      subtitle: Text(lines.join("\n")),
      isThreeLine: lines.length > 1,
      trailing: Text(time),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = context.watch<PlayerState>();
    final messages = playerState.inbox.reversed.toList();

    // Els missatges rebuts es marquen com a vistos en obrir aquesta
    // pantalla. Només es programa si n'hi ha de pendents, així no es repeteix.
    if (playerState.unreadMessages > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<PlayerState>().markMessagesSeen();
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Missatges")),
      body: messages.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Encara no tens cap missatge. Toca «Nou missatge» per "
                  "escriure a un altre jugador.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              // Espai al final perquè el botó flotant no tapi l'últim missatge.
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: messages.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _buildTile(context, messages[index]),
            ),
      floatingActionButton: playerState.sessionFinished
          ? null
          : FloatingActionButton.extended(
              onPressed: _compose,
              icon: const Icon(Icons.edit_outlined),
              label: const Text("Nou missatge"),
            ),
    );
  }
}
