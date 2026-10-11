import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/minigame_model.dart';
import '../../state/master_state.dart';

/// Una fila editable del sistema de puntuació: o bé una posició exacta
/// (1r, 2n...) o bé la regla especial "últim/a".
class _RuleDraft {
  final bool isLast;
  final TextEditingController positionController;
  final TextEditingController pointsController;

  _RuleDraft.exact({required int position, required int points})
      : isLast = false,
        positionController = TextEditingController(text: position.toString()),
        pointsController = TextEditingController(text: points.toString());

  _RuleDraft.last({required int points})
      : isLast = true,
        positionController = TextEditingController(),
        pointsController = TextEditingController(text: points.toString());

  void dispose() {
    positionController.dispose();
    pointsController.dispose();
  }
}

class MinigameEditorScreen extends StatefulWidget {
  const MinigameEditorScreen({super.key, this.existing});

  /// Si és `null`, es crea un minijoc nou; si no, s'edita aquest.
  final MinigameModel? existing;

  @override
  State<MinigameEditorScreen> createState() => _MinigameEditorScreenState();
}

class _MinigameEditorScreenState extends State<MinigameEditorScreen> {
  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _rulesController =
      TextEditingController(text: widget.existing?.rules ?? '');
  late final List<_RuleDraft> _rules = _initialRules();

  bool _saving = false;

  List<_RuleDraft> _initialRules() {
    final existing = widget.existing;
    if (existing == null) return [];
    return existing.scoring
        .map((rule) => rule.isLastPlace
            ? _RuleDraft.last(points: rule.points)
            : _RuleDraft.exact(position: rule.position!, points: rule.points))
        .toList();
  }

  bool get _hasLastRule => _rules.any((r) => r.isLast);

  void _addPositionRule() {
    var next = 1;
    for (final r in _rules) {
      if (r.isLast) continue;
      final value = int.tryParse(r.positionController.text) ?? 0;
      if (value >= next) next = value + 1;
    }
    setState(() => _rules.add(_RuleDraft.exact(position: next, points: 0)));
  }

  void _addLastRule() {
    if (_hasLastRule) return;
    setState(() => _rules.add(_RuleDraft.last(points: 0)));
  }

  void _removeRule(_RuleDraft rule) {
    setState(() {
      _rules.remove(rule);
      rule.dispose();
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError("Posa un nom al minijoc.");
      return;
    }
    if (_rules.isEmpty) {
      _showError("Afegeix almenys una regla de puntuació.");
      return;
    }

    final scoring = <ScoringRule>[];
    final usedPositions = <int>{};
    for (final draft in _rules) {
      final points = int.tryParse(draft.pointsController.text.trim());
      if (points == null) {
        _showError("Hi ha una puntuació que no és un número vàlid.");
        return;
      }
      if (draft.isLast) {
        scoring.add(ScoringRule.last(points: points));
        continue;
      }
      final position = int.tryParse(draft.positionController.text.trim());
      if (position == null || position < 1) {
        _showError("Les posicions han de ser 1, 2, 3...");
        return;
      }
      if (!usedPositions.add(position)) {
        _showError("Hi ha dues regles per a la posició $position.");
        return;
      }
      scoring.add(ScoringRule.exact(pos: position, points: points));
    }

    setState(() => _saving = true);
    final master = context.read<MasterState>();
    if (widget.existing == null) {
      await master.createMinigame(
        name: name,
        description: _descriptionController.text,
        rules: _rulesController.text,
        scoring: scoring,
      );
    } else {
      await master.updateMinigame(
        widget.existing!.id,
        name: name,
        description: _descriptionController.text,
        rules: _rulesController.text,
        scoring: scoring,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    for (final r in _rules) {
      r.dispose();
    }
    super.dispose();
  }

  Widget _buildRuleRow(_RuleDraft draft) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (draft.isLast)
            const Expanded(child: Text("Qui quedi últim/a"))
          else ...[
            SizedBox(
              width: 76,
              child: TextField(
                controller: draft.positionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Posició"),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
          SizedBox(
            width: 96,
            child: TextField(
              controller: draft.pointsController,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(labelText: "Punts"),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeRule(draft),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Editar minijoc" : "Nou minijoc")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "Nom"),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: "Descripció"),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _rulesController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: "Normes"),
          ),
          const SizedBox(height: 24),
          Text(
            "Sistema de puntuació",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._rules.map(_buildRuleRow),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _addPositionRule,
                icon: const Icon(Icons.add),
                label: const Text("Posició"),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _hasLastRule ? null : _addLastRule,
                icon: const Icon(Icons.add),
                label: const Text("Últim/a"),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Desar minijoc"),
          ),
        ],
      ),
    );
  }
}
