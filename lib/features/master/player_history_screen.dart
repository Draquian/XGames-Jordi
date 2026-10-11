import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/player_model.dart';
import '../../state/master_state.dart';

/// Historial complet d'UN jugador (resultats de minijocs + ajustaments
/// manuals), amb la possibilitat que el màster afegeixi un ajustament nou
/// (una correcció, una penalització, un extra...).
class PlayerHistoryScreen extends StatefulWidget {
  const PlayerHistoryScreen({super.key, required this.player});

  final PlayerModel player;

  @override
  State<PlayerHistoryScreen> createState() => _PlayerHistoryScreenState();
}

class _PlayerHistoryScreenState extends State<PlayerHistoryScreen> {
  List<Map<String, Object?>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final history = await context
        .read<MasterState>()
        .loadHistoryForPlayer(widget.player.id);
    if (!mounted) return;
    setState(() {
      _history = history;
      _loading = false;
    });
  }

  Future<void> _openAddAdjustmentDialog() async {
    final deltaController = TextEditingController();
    final reasonController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Afegir ajustament"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: deltaController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: "Punts (poden ser negatius)",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: "Motiu"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Cancel·lar"),
          ),
          FilledButton(
            onPressed: () {
              final delta = int.tryParse(deltaController.text.trim());
              final reason = reasonController.text.trim();
              if (delta == null || reason.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(
                  content: Text("Posa una puntuació vàlida i un motiu."),
                ));
                return;
              }
              Navigator.of(dialogContext).pop(true);
              context.read<MasterState>().addPointAdjustment(
                    playerId: widget.player.id,
                    delta: delta,
                    reason: reason,
                  );
            },
            child: const Text("Desar"),
          ),
        ],
      ),
    );
    deltaController.dispose();
    reasonController.dispose();
    if (saved == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final master = context.watch<MasterState>();
    final totalPoints = master.totalPointsFor(widget.player.id);

    return Scaffold(
      appBar: AppBar(title: Text(widget.player.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          "$totalPoints",
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Text("punts totals"),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openAddAdjustmentDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Afegir ajustament"),
                ),
                const SizedBox(height: 24),
                Text(
                  "Historial",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text("Encara no hi ha cap resultat."),
                  )
                else
                  ..._history.reversed.map((entry) {
                    final isAdjustment = entry['type'] == 'adjustment';
                    final points = entry['points'] as int? ?? 0;
                    final label = entry['label'] as String? ?? '';
                    return ListTile(
                      leading:
                          Icon(isAdjustment ? Icons.tune : Icons.emoji_events_outlined),
                      title: Text(label),
                      subtitle: isAdjustment
                          ? const Text("Ajustament manual")
                          : Text("Posició ${entry['position']}"),
                      trailing: Text(
                        "${points >= 0 ? '+' : ''}$points",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
