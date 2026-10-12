import 'package:flutter/material.dart';

/// Mostra el podi final: els tres primers amb medalla (🥇🥈🥉) i la resta
/// ordenats a sota. S'adapta sola si hi ha menys de tres jugadors.
class PodiumView extends StatelessWidget {
  const PodiumView({super.key, required this.standings});

  /// Ja ordenada de més a menys punts, amb `name` i `totalPoints`.
  final List<Map<String, Object?>> standings;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return const Center(
        child: Text("No hi ha cap jugador a la classificació final."),
      );
    }
    final top = standings.take(3).toList();
    final rest = standings.skip(3).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Column(
            children: [
              const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
              const SizedBox(height: 8),
              Text(
                "Partida finalitzada!",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < top.length; i++)
          Card(
            color: i == 0
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              leading: Text(_medals[i], style: const TextStyle(fontSize: 28)),
              title: Text(
                top[i]['name'] as String? ?? '',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              trailing: Text(
                "${top[i]['totalPoints']} punts",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          for (var i = 0; i < rest.length; i++)
            ListTile(
              leading: CircleAvatar(child: Text("${i + 4}")),
              title: Text(rest[i]['name'] as String? ?? ''),
              trailing: Text("${rest[i]['totalPoints']} punts"),
            ),
        ],
      ],
    );
  }
}
