import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_state.dart';

/// Pantalla completa amb els resultats i estadístiques del propi
/// jugador. Només mostra les seves pròpies dades: mai les de la resta.
class MyStatsScreen extends StatelessWidget {
  const MyStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerState = context.watch<PlayerState>();
    final history = playerState.myHistory;
    final minigamesPlayed =
        history.where((e) => e['type'] == 'result').length;

    return Scaffold(
      appBar: AppBar(title: const Text("Els meus resultats")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    "${playerState.myTotalPoints}",
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Text("punts totals"),
                  const SizedBox(height: 8),
                  Text("$minigamesPlayed minijocs jugats"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                "Encara no tens cap resultat. Quan el màster finalitzi un "
                "minijoc, ho veuràs aquí.",
              ),
            )
          else
            ...history.reversed.map((entry) {
              final type = entry['type'] as String? ?? 'result';
              final points = entry['points'] as int? ?? 0;
              final label = entry['label'] as String? ?? '';
              return ListTile(
                leading: Icon(_iconForType(type)),
                title: Text(label),
                subtitle: Text(_subtitleForEntry(type, entry)),
                trailing: Text(
                  "${points >= 0 ? '+' : ''}$points",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: points < 0
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

IconData _iconForType(String type) {
  switch (type) {
    case 'adjustment':
      return Icons.tune;
    case 'transfer':
      return Icons.swap_horiz;
    default:
      return Icons.emoji_events_outlined;
  }
}

String _subtitleForEntry(String type, Map<String, Object?> entry) {
  switch (type) {
    case 'adjustment':
      return "Ajustament del màster";
    case 'transfer':
      return "Transferència entre jugadors";
    default:
      return "Posició ${entry['position']}";
  }
}
