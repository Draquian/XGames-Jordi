import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_state.dart';
import '../role_select_screen.dart';
import '../shared/reconnecting_banner.dart';

class PlayerLobbyScreen extends StatefulWidget {
  const PlayerLobbyScreen({super.key});

  @override
  State<PlayerLobbyScreen> createState() => _PlayerLobbyScreenState();
}

class _PlayerLobbyScreenState extends State<PlayerLobbyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playerState = context.read<PlayerState>();
      if (!playerState.connected) {
        playerState.tryAutoReconnect();
      }
    });
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
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  playerState.myName.isEmpty
                      ? "Connectant..."
                      : "Hola, ${playerState.myName}",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  "Esperant que el màster comenci el primer minijoc...",
                ),
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
                      p['status'] == 'connected'
                          ? "Connectat"
                          : "Desconnectat",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
