import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/minigame_model.dart';
import '../../state/master_state.dart';
import 'minigame_editor_screen.dart';

class MinigameListScreen extends StatelessWidget {
  const MinigameListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final master = context.watch<MasterState>();
    final minigames = master.minigames;

    return Scaffold(
      appBar: AppBar(title: const Text("Minijocs")),
      body: minigames.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Encara no has creat cap minijoc. Toca el botó '+' per "
                  "crear-ne el primer.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: minigames.length,
              itemBuilder: (context, i) => _MinigameTile(minigame: minigames[i]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MinigameEditorScreen()),
        ),
        tooltip: "Nou minijoc",
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MinigameTile extends StatelessWidget {
  const _MinigameTile({required this.minigame});

  final MinigameModel minigame;

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

  @override
  Widget build(BuildContext context) {
    final rulesCount = minigame.scoring.length;
    return Card(
      child: ListTile(
        leading: Icon(_statusIcon),
        title: Text(minigame.name),
        subtitle: Text(
          "$_statusLabel · $rulesCount ${rulesCount == 1 ? 'regla' : 'regles'} de puntuació",
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MinigameEditorScreen(existing: minigame),
          ),
        ),
      ),
    );
  }
}
