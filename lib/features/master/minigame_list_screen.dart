import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/minigame_model.dart';
import '../../data/models/session_model.dart';
import '../../state/master_state.dart';
import 'minigame_editor_screen.dart';
import 'minigame_results_screen.dart';

class MinigameListScreen extends StatelessWidget {
  const MinigameListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final master = context.watch<MasterState>();
    final minigames = master.minigames;
    final activeId = master.session?.currentMinigameId;
    final sessionFinished =
        master.session?.status == SessionStatus.finished;
    MinigameModel? active;
    if (activeId != null) {
      for (final m in minigames) {
        if (m.id == activeId) active = m;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Minijocs")),
      body: Column(
        children: [
          if (active != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.primaryContainer,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text("Minijoc en curs: ${active.name}")),
                  FilledButton(
                    // Dins d'un Row, el tema (minimumSize amb amplada infinita)
                    // provoca un error de layout: cal una amplada mínima finita.
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MinigameResultsScreen(minigame: active!),
                      ),
                    ),
                    child: const Text("Anar-hi"),
                  ),
                ],
              ),
            ),
          Expanded(
            child: minigames.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Encara no has creat cap minijoc. Toca el botó '+' "
                        "per crear-ne el primer.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: minigames.length,
                    itemBuilder: (context, i) => _MinigameTile(
                      minigame: minigames[i],
                      anotherOneActive: activeId != null &&
                          activeId != minigames[i].id,
                      disabled: sessionFinished,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: sessionFinished
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MinigameEditorScreen(),
                ),
              ),
              tooltip: "Nou minijoc",
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _MinigameTile extends StatelessWidget {
  const _MinigameTile({
    required this.minigame,
    required this.anotherOneActive,
    required this.disabled,
  });

  final MinigameModel minigame;

  /// Si `true`, ja hi ha un ALTRE minijoc en curs i aquest no es pot
  /// començar ara mateix.
  final bool anotherOneActive;

  /// Si `true`, la partida ja ha finalitzat i no es poden començar més
  /// minijocs (encara es poden consultar o corregir resultats).
  final bool disabled;

  IconData get _statusIcon {
    switch (minigame.status) {
      case MinigameStatus.pending:
        return Icons.hourglass_empty;
      case MinigameStatus.inProgress:
        return Icons.play_circle_outline;
      case MinigameStatus.finished:
        return Icons.check_circle_outline;
    }
  }

  String get _statusLabel {
    switch (minigame.status) {
      case MinigameStatus.pending:
        return "Pendent";
      case MinigameStatus.inProgress:
        return "En curs";
      case MinigameStatus.finished:
        return "Finalitzat";
    }
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MinigameEditorScreen(existing: minigame),
      ),
    );
  }

  void _openResults(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MinigameResultsScreen(minigame: minigame),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rulesCount = minigame.scoring.length;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(_statusIcon),
            title: Text(minigame.name),
            subtitle: Text(
              "$_statusLabel · $rulesCount ${rulesCount == 1 ? 'regla' : 'regles'} de puntuació",
            ),
            onTap: () => minigame.status == MinigameStatus.pending
                ? _openEditor(context)
                : _openResults(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _openEditor(context),
                  child: const Text("Editar"),
                ),
                if (minigame.status == MinigameStatus.pending)
                  FilledButton(
                    onPressed: (anotherOneActive || disabled)
                        ? null
                        : () => context
                            .read<MasterState>()
                            .startMinigame(minigame.id),
                    child: const Text("Començar"),
                  )
                else if (minigame.status == MinigameStatus.inProgress)
                  FilledButton(
                    onPressed: () => _openResults(context),
                    child: const Text("Finalitzar minijoc"),
                  )
                else
                  OutlinedButton(
                    onPressed: () => _openResults(context),
                    child: const Text("Veure resultats"),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
