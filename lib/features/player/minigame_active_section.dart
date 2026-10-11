import 'package:flutter/material.dart';

/// El que veu un jugador MENTRE el màster té un minijoc en curs: nom,
/// descripció, normes i la informació necessària per jugar. No hi ha cap
/// manera de tocar punts ni resultats des d'aquí: només el màster ho pot
/// fer.
class MinigameActiveSection extends StatelessWidget {
  const MinigameActiveSection({super.key, required this.minigame});

  final Map<String, Object?> minigame;

  @override
  Widget build(BuildContext context) {
    final name = minigame['name'] as String? ?? '';
    final description = minigame['description'] as String? ?? '';
    final rules = minigame['rules'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                "Minijoc en curs",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(name, style: Theme.of(context).textTheme.headlineSmall),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "Descripció",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(description),
          ],
          if (rules.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text("Normes", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(rules),
          ],
          const SizedBox(height: 24),
          const Text(
            "El màster controla quan comença i acaba. Quan acabi, veuràs "
            "aquí mateix els punts que has aconseguit.",
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
