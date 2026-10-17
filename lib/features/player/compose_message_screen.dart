import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/player_message_model.dart';
import '../../state/player_state.dart';

/// Escriure un missatge privat a un altre jugador i, si es vol, enviar-li
/// també part dels propis punts. El màster valida l'enviament: aquí només
/// es demana.
class ComposeMessageScreen extends StatefulWidget {
  const ComposeMessageScreen({super.key});

  @override
  State<ComposeMessageScreen> createState() => _ComposeMessageScreenState();
}

class _ComposeMessageScreenState extends State<ComposeMessageScreen> {
  final _bodyController = TextEditingController();
  final _pointsController = TextEditingController();
  String? _recipientId;
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _bodyController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  String _messageForReason(String reason) {
    switch (reason) {
      case 'not_enough_points':
        return "No tens prou punts.";
      case 'finished':
        return "La partida ja ha acabat.";
      case 'invalid_recipient':
        return "Aquest jugador ja no és a la partida.";
      case 'self':
        return "No et pots enviar res a tu mateix.";
      case 'empty':
        return "Escriu un missatge o indica punts.";
      case 'too_long':
        return "El missatge és massa llarg.";
      case 'invalid_points':
        return "Els punts han de ser un número enter positiu.";
      case 'offline':
        return "No hi ha connexió amb el màster. Torna-ho a provar quan es "
            "reconnecti.";
      case 'timeout':
        return "No s'ha pogut confirmar l'enviament. Mira els teus missatges "
            "i resultats abans de tornar-ho a provar.";
      case 'points_to_master':
        return "Al màster no se li poden enviar punts.";
      case 'busy':
        return "Encara s'està enviant l'anterior.";
      default:
        return "No s'ha pogut enviar.";
    }
  }

  Future<void> _send() async {
    final playerState = context.read<PlayerState>();
    final recipientId = _recipientId;
    if (recipientId == null) {
      setState(() => _error = "Tria a qui ho vols enviar.");
      return;
    }

    final body = _bodyController.text.trim();
    final pointsText = recipientId == masterRecipientId
        ? ''
        : _pointsController.text.trim();
    final points = pointsText.isEmpty ? 0 : int.tryParse(pointsText);
    if (points == null || points < 0) {
      setState(() => _error = "Els punts han de ser un número enter positiu.");
      return;
    }
    if (body.isEmpty && points == 0) {
      setState(() => _error = "Escriu un missatge o indica punts.");
      return;
    }
    if (points > playerState.myTotalPoints) {
      setState(() => _error =
          "No tens prou punts (en tens ${playerState.myTotalPoints}).");
      return;
    }

    if (points > 0) {
      var recipientName = '';
      for (final p in playerState.roster) {
        if (p['id'] == recipientId) recipientName = p['name'] as String? ?? '';
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text("Enviar $points punts?"),
          content: Text(
            "Es restaran dels teus punts i se sumaran als de $recipientName.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancel·lar"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Enviar"),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    final reason = await playerState.sendMessage(
      toPlayerId: recipientId,
      body: body,
      points: points,
    );
    if (!mounted) return;
    if (reason == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _error = _messageForReason(reason);
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = context.watch<PlayerState>();
    final myId = playerState.playerId;
    final recipients =
        playerState.roster.where((p) => p['id'] != myId).toList();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Nou missatge")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text("Per a", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            color: _recipientId == masterRecipientId
                ? scheme.primaryContainer
                : null,
            child: ListTile(
              leading: Icon(
                _recipientId == masterRecipientId
                    ? Icons.check_circle
                    : Icons.support_agent,
              ),
              title: const Text("Màster"),
              subtitle: const Text("Només missatge, sense punts"),
              onTap: () => setState(() {
                _recipientId = masterRecipientId;
                _pointsController.clear();
              }),
            ),
          ),
          if (recipients.isEmpty)
            const Text("Encara no hi ha cap altre jugador a la partida.")
          else
            ...recipients.map((p) {
              final id = p['id'] as String? ?? '';
              final selected = id == _recipientId;
              final connected = p['status'] == 'connected';
              return Card(
                color: selected ? scheme.primaryContainer : null,
                child: ListTile(
                  leading: Icon(
                    selected ? Icons.check_circle : Icons.person_outline,
                  ),
                  title: Text(p['name'] as String? ?? ''),
                  subtitle: connected
                      ? null
                      : const Text("Desconnectat: ho rebrà quan torni"),
                  onTap: () => setState(() => _recipientId = id),
                ),
              );
            }),
          const SizedBox(height: 24),
          TextField(
            controller: _bodyController,
            maxLines: 4,
            maxLength: 280,
            decoration: const InputDecoration(labelText: "Missatge"),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pointsController,
            keyboardType: TextInputType.number,
            enabled: _recipientId != masterRecipientId,
            decoration: InputDecoration(
              labelText: "Punts a enviar (opcional)",
              helperText: _recipientId == masterRecipientId
                  ? "Al màster no se li poden enviar punts"
                  : "Tens ${playerState.myTotalPoints} punts",
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Enviar"),
          ),
        ],
      ),
    );
  }
}
