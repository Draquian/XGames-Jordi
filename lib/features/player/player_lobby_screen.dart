import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_state.dart';
import '../role_select_screen.dart';
import '../shared/podium_view.dart';
import '../shared/reconnecting_banner.dart';
import 'messages_screen.dart';
import 'minigame_active_section.dart';
import 'my_stats_screen.dart';

class PlayerLobbyScreen extends StatefulWidget {
  const PlayerLobbyScreen({super.key});

  @override
  State<PlayerLobbyScreen> createState() => _PlayerLobbyScreenState();
}

class _PlayerLobbyScreenState extends State<PlayerLobbyScreen> {
  StreamSubscription<Map<String, Object?>>? _incomingSub;

  @override
  void initState() {
    super.initState();
    _incomingSub =
        context.read<PlayerState>().incomingMessages.listen(_onIncoming);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playerState = context.read<PlayerState>();
      if (!playerState.connected) {
        playerState.tryAutoReconnect();
      }
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }

  void _openMessages() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MessagesScreen()),
    );
  }

  /// Avís en pantalla quan arriba un missatge nou mentre l'app és oberta.
  void _onIncoming(Map<String, Object?> message) {
    if (!mounted) return;
    final from = message['otherName'] as String? ?? '';
    final body = message['body'] as String? ?? '';
    final points = message['points'] as int? ?? 0;
    final text = points > 0
        ? (body.isEmpty
            ? "$from t'ha enviat $points punts"
            : "$from t'ha enviat un missatge i $points punts")
        : "Nou missatge de $from";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        action: SnackBarAction(label: "Veure", onPressed: _openMessages),
      ),
    );
  }

  void _leave() {
    context.read<PlayerState>().leaveSession();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = context.watch<PlayerState>();

    if (playerState.kicked) {
      return Scaffold(
        appBar: AppBar(title: const Text("Navidad de Jordi")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 48),
                const SizedBox(height: 16),
                const Text("El màster t'ha expulsat de la partida."),
                const SizedBox(height: 24),
                FilledButton(onPressed: _leave, child: const Text("Sortir")),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          playerState.sessionName.isEmpty
              ? "Navidad de Jordi"
              : playerState.sessionName,
        ),
        actions: [
          IconButton(
            onPressed: _openMessages,
            icon: Badge(
              isLabelVisible: playerState.unreadMessages > 0,
              label: Text('${playerState.unreadMessages}'),
              child: const Icon(Icons.mail_outline),
            ),
            tooltip: "Missatges",
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyStatsScreen()),
            ),
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: "Els meus resultats",
          ),
          IconButton(
            onPressed: _leave,
            icon: const Icon(Icons.logout),
            tooltip: "Sortir",
          ),
        ],
      ),
      body: Column(
        children: [
          if (!playerState.connected) const ReconnectingBanner(),
          Expanded(
            child: playerState.sessionFinished
                ? PodiumView(standings: playerState.finalStandings)
                : playerState.activeMinigame != null
                    ? MinigameActiveSection(
                        minigame: playerState.activeMinigame!,
                      )
                    : _WaitingView(playerState: playerState),
          ),
        ],
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.playerState});

  final PlayerState playerState;

  @override
  Widget build(BuildContext context) {
    final hasHistory = playerState.myHistory.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          playerState.myName.isEmpty
              ? "Connectant..."
              : "Hola, ${playerState.myName}",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          hasHistory
              ? "Portes ${playerState.myTotalPoints} punts."
              : "Esperant que el màster comenci el primer minijoc...",
        ),
        if (hasHistory) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text("${playerState.myTotalPoints} punts"),
              subtitle: const Text("Veure el desglossament complet"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyStatsScreen()),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        Text(
          "Jugadors a la partida",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...playerState.roster.map(
          (p) => ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(p['name'] as String? ?? ''),
            subtitle: Text(
              p['status'] == 'connected' ? "Connectat" : "Desconnectat",
            ),
          ),
        ),
      ],
    );
  }
}
