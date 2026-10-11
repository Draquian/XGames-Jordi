import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/player_model.dart';
import '../../state/master_state.dart';
import 'player_history_screen.dart';

/// Classificació general: TOTS els jugadors (també els desconnectats i
/// els expulsats, que mantenen els seus punts i historial), ordenats de
/// més a menys punts. Un empat es mostra amb la mateixa posició.
class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final master = context.watch<MasterState>();
    final players = master.rankedPlayers;

    return Scaffold(
      appBar: AppBar(title: const Text("Classificació")),
      body: players.isEmpty
          ? const Center(child: Text("Encara no hi ha jugadors."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: players.length,
              itemBuilder: (context, i) {
                final player = players[i];
                final points = master.totalPointsFor(player.id);
                // Rànquing "de competició": si empata amb algú anterior,
                // mostra la mateixa posició (1, 2, 2, 4...).
                final rank = players.indexWhere(
                      (p) => master.totalPointsFor(p.id) == points,
                    ) +
                    1;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text("$rank")),
                    title: Text(player.name),
                    subtitle: Text(_statusLabel(player.status)),
                    trailing: Text(
                      "$points punts",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlayerHistoryScreen(player: player),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _statusLabel(PlayerStatus status) {
    switch (status) {
      case PlayerStatus.connected:
        return "Connectat";
      case PlayerStatus.disconnected:
        return "Desconnectat";
      case PlayerStatus.kicked:
        return "Expulsat";
    }
  }
}
