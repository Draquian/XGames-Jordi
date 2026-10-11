import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/minigame_model.dart';
import '../../data/models/player_model.dart';
import '../../state/master_state.dart';

/// Introducció (o correcció) dels resultats d'un minijoc: una posició per
/// jugador. Deixar el camp en blanc vol dir "no hi ha jugat". Dos
/// jugadors poden tenir la mateixa posició: és exactament com es
/// representa un empat, que el màster decideix manualment.
class MinigameResultsScreen extends StatefulWidget {
  const MinigameResultsScreen({super.key, required this.minigame});

  final MinigameModel minigame;

  @override
  State<MinigameResultsScreen> createState() => _MinigameResultsScreenState();
}

class _MinigameResultsScreenState extends State<MinigameResultsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  List<PlayerModel> _eligiblePlayers = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final master = context.read<MasterState>();
    final positions =
        await master.loadPositionsForMinigame(widget.minigame.id);
    final eligible = <PlayerModel>[];
    for (final p in master.players) {
      final hasExistingResult = positions.containsKey(p.id);
      if (p.status == PlayerStatus.kicked && !hasExistingResult) {
        // Expulsat i mai va jugar aquest minijoc: no cal mostrar-lo.
        continue;
      }
      eligible.add(p);
      _controllers[p.id] = TextEditingController(
        text: positions[p.id]?.toString() ?? '',
      );
    }
    if (!mounted) return;
    setState(() {
      _eligiblePlayers = eligible;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final positions = <String, int>{};
    for (final player in _eligiblePlayers) {
      final text = _controllers[player.id]!.text.trim();
      if (text.isEmpty) continue;
      final position = int.tryParse(text);
      if (position == null || position < 1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            "La posició de ${player.name} no és vàlida (1, 2, 3...).",
          ),
        ));
        return;
      }
      positions[player.id] = position;
    }
    if (positions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Introdueix la posició d'almenys un jugador."),
      ));
      return;
    }

    setState(() => _saving = true);
    await context.read<MasterState>().finishMinigame(
          minigameId: widget.minigame.id,
          positionsByPlayerId: positions,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alreadyFinished = widget.minigame.status == MinigameStatus.finished;
    return Scaffold(
      appBar: AppBar(title: Text(widget.minigame.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  "Posa la posició de cada jugador (1r, 2n...). Si dos han "
                  "empatat, posa'ls la mateixa posició. Deixa en blanc qui "
                  "no hi hagi jugat.",
                ),
                const SizedBox(height: 24),
                if (_eligiblePlayers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text("Encara no s'ha unit cap jugador."),
                  )
                else
                  ..._eligiblePlayers.map((player) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                player.status == PlayerStatus.kicked
                                    ? "${player.name} (expulsat)"
                                    : player.name,
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _controllers[player.id],
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(labelText: "Posició"),
                              ),
                            ),
                          ],
                        ),
                      )),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          alreadyFinished
                              ? "Desar canvis"
                              : "Finalitzar minijoc",
                        ),
                ),
              ],
            ),
    );
  }
}
