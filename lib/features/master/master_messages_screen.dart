import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/master_state.dart';

/// Missatges que els jugadors han enviat al màster. Només els veu el
/// màster (els altres jugadors no). Des d'aquí no es pot respondre.
class MasterMessagesScreen extends StatefulWidget {
  const MasterMessagesScreen({super.key});

  @override
  State<MasterMessagesScreen> createState() => _MasterMessagesScreenState();
}

class _MasterMessagesScreenState extends State<MasterMessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final master = context.watch<MasterState>();
    final messages = master.masterInbox.reversed.toList();

    // En obrir aquesta pantalla, els missatges es marquen com a vistos.
    // Només es programa si n'hi ha de pendents, així no es repeteix.
    if (master.unreadMasterMessages > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<MasterState>().markMasterMessagesSeen();
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Missatges dels jugadors")),
      body: messages.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Encara no has rebut cap missatge dels jugadors.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              itemCount: messages.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final m = messages[index];
                final ms = m['createdAtMs'] as int? ?? 0;
                final time = TimeOfDay.fromDateTime(
                  DateTime.fromMillisecondsSinceEpoch(ms),
                ).format(context);
                return ListTile(
                  leading: const Icon(Icons.call_received),
                  title: Text("De ${m['fromName'] ?? ''}"),
                  subtitle: Text(m['body'] as String? ?? ''),
                  trailing: Text(time),
                );
              },
            ),
    );
  }
}
