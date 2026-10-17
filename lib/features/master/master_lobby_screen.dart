import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/player_model.dart';
import '../../data/models/session_model.dart';
import '../../state/master_state.dart';
import 'final_podium_screen.dart';
import 'master_message_toaster.dart';
import 'master_messages_screen.dart';
import 'minigame_list_screen.dart';
import 'player_history_screen.dart';
import 'ranking_screen.dart';

class MasterLobbyScreen extends StatelessWidget {
  const MasterLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final master = context.watch<MasterState>();
    final session = master.session;
    final connectionInfo = master.connectionInfo;

    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MasterMessageToaster(
      child: Scaffold(
      appBar: AppBar(
        title: Text(session.name),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: master.unreadMasterMessages > 0,
              label: Text('${master.unreadMasterMessages}'),
              child: const Icon(Icons.mail_outline),
            ),
            tooltip: "Missatges dels jugadors",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MasterMessagesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: "Classificació",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RankingScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.extension_outlined),
            tooltip: "Minijocs",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MinigameListScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.leaderboard_outlined),
              title: const Text("Classificació"),
              subtitle: const Text("Punts totals i historial de tots els jugadors"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RankingScreen()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.extension_outlined),
              title: Text("Minijocs (${master.minigames.length})"),
              subtitle: const Text("Crear i editar els minijocs de la partida"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MinigameListScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (connectionInfo == null)
            Column(
              children: [
                const Text(
                  "Aquest mòbil no té cap xarxa WiFi activa. Connecta't al "
                  "router de la festa o activa el teu punt d'accés "
                  "personal des dels Ajustos.",
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      context.read<MasterState>().refreshLocalIp(),
                  child: const Text("Ja ho he fet, torna-ho a provar"),
                ),
              ],
            )
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: connectionInfo.toQrPayload(),
                  size: 220,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  const Text("O introduïu aquest codi a l'app:"),
                  const SizedBox(height: 4),
                  Text(
                    session.joinCode,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Adreça manual: ${connectionInfo.host}:${connectionInfo.port}",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Tancar la sessió a noves incorporacions"),
            subtitle: const Text(
              "Els jugadors que ja s'hi han unit sempre podran reconnectar-se",
            ),
            value: session.lockedForNewPlayers,
            onChanged: (value) =>
                context.read<MasterState>().setLockedForNewPlayers(value),
          ),
          const SizedBox(height: 16),
          Text(
            "Jugadors (${master.players.where((p) => p.status != PlayerStatus.kicked).length})",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (master.players.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text("Encara no s'ha unit ningú."),
            )
          else
            ...master.players
                .where((p) => p.status != PlayerStatus.kicked)
                .map((p) => _PlayerTile(player: p)),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          if (session.status == SessionStatus.finished)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FinalPodiumScreen()),
              ),
              icon: const Icon(Icons.emoji_events_outlined),
              label: const Text("Veure el podi final"),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              onPressed: () => _confirmEndSession(context),
              icon: const Icon(Icons.flag_outlined),
              label: const Text("Finalitzar la partida"),
            ),
        ],
      ),
      ),
    );
  }
}

Future<void> _confirmEndSession(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Finalitzar la partida?"),
      content: const Text(
        "Es mostrarà el podi final a tots els jugadors i la sessió es "
        "tancarà a noves incorporacions. Assegura't que no hi ha cap "
        "minijoc en curs.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text("Cancel·lar"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text("Finalitzar"),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final master = context.read<MasterState>();
  final ok = await master.endSession();
  if (!context.mounted) return;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Finalitza primer el minijoc que està en curs."),
    ));
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const FinalPodiumScreen()),
  );
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player});

  final PlayerModel player;

  @override
  Widget build(BuildContext context) {
    final connected = player.status == PlayerStatus.connected;
    final points = context.watch<MasterState>().totalPointsFor(player.id);
    return ListTile(
      leading: Icon(
        connected ? Icons.circle : Icons.circle_outlined,
        size: 14,
        color: connected ? Colors.green : Colors.grey,
      ),
      title: Text(player.name),
      subtitle: Text(connected ? "Connectat" : "Desconnectat"),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerHistoryScreen(player: player),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$points pts"),
          IconButton(
            icon: const Icon(Icons.person_remove_outlined),
            tooltip: "Expulsar",
            onPressed: () => _confirmKick(context),
          ),
        ],
      ),
    );
  }

  void _confirmKick(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Expulsar ${player.name}?"),
        content: const Text(
          "Es tallarà la seva connexió. Els seus punts i historial es "
          "mantindran, marcats com a expulsat.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Cancel·lar"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<MasterState>().kickPlayer(player.id);
            },
            child: const Text("Expulsar"),
          ),
        ],
      ),
    );
  }
}
