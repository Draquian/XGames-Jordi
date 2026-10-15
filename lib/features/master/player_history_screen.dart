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

  /// Obre el diàleg i, NOMÉS quan ja s'ha tancat, desa l'ajustament i
  /// recarrega l'historial. El diàleg gestiona els seus propis camps de
  /// text (vegeu `_AdjustmentDialog`), així no cal alliberar-los aquí.
  Future<void> _openAddAdjustmentDialog() async {
    final input = await showDialog<_AdjustmentInput>(
      context: context,
      builder: (_) => const _AdjustmentDialog(),
    );
    if (input == null || !mounted) return;
    await context.read<MasterState>().addPointAdjustment(
          playerId: widget.player.id,
          delta: input.delta,
          reason: input.reason,
        );
    if (!mounted) return;
    await _load();
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
                    final type = entry['type'] as String? ?? 'result';
                    final points = entry['points'] as int? ?? 0;
                    final label = entry['label'] as String? ?? '';
                    return ListTile(
                      leading: Icon(_iconForType(type)),
                      title: Text(label),
                      subtitle: Text(_subtitleForEntry(type, entry)),
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

/// El que retorna el diàleg quan el màster prem "Desar".
class _AdjustmentInput {
  const _AdjustmentInput(this.delta, this.reason);

  final int delta;
  final String reason;
}

/// Diàleg per afegir un ajustament de punts. Té els seus propis
/// controladors de text i els allibera al seu `dispose`, que Flutter
/// crida quan el diàleg ja ha desaparegut del tot (després de
/// l'animació de tancament). Alliberar-los des de fora, just després de
/// tancar-lo, provoca errors de framework.
class _AdjustmentDialog extends StatefulWidget {
  const _AdjustmentDialog();

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  final _deltaController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _deltaController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final delta = int.tryParse(_deltaController.text.trim());
    final reason = _reasonController.text.trim();
    if (delta == null || reason.isEmpty) {
      setState(() => _error = "Posa una puntuació vàlida i un motiu.");
      return;
    }
    Navigator.of(context).pop(_AdjustmentInput(delta, reason));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Afegir ajustament"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _deltaController,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(
              labelText: "Punts (poden ser negatius)",
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: "Motiu"),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel·lar"),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text("Desar"),
        ),
      ],
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
      return "Ajustament manual";
    case 'transfer':
      return "Transferència entre jugadors";
    default:
      return "Posició ${entry['position']}";
  }
}
