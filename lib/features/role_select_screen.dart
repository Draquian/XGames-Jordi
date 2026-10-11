import 'package:flutter/material.dart';

import '../data/local/player_cache.dart';
import 'master/master_home_screen.dart';
import 'player/player_join_screen.dart';
import 'player/player_lobby_screen.dart';

/// Primera pantalla que veu qualsevol dispositiu en obrir l'app. Només el
/// dispositiu que tria "Sóc el màster" i crea la sessió té permisos de
/// màster; ningú més els pot obtenir.
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  SavedConnection? _savedConnection;

  @override
  void initState() {
    super.initState();
    PlayerCache.loadConnection().then((value) {
      if (mounted) setState(() => _savedConnection = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_outlined, size: 72),
              const SizedBox(height: 16),
              Text(
                "Navidad de Jordi",
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Marcador de minijocs sense necessitat d'Internet",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MasterHomeScreen()),
                ),
                child: const Text("Sóc el màster"),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlayerJoinScreen()),
                ),
                child: const Text("Sóc jugador/a"),
              ),
              if (_savedConnection != null) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlayerLobbyScreen(),
                    ),
                  ),
                  child: Text(
                    "Tornar a la partida com a ${_savedConnection!.playerName}",
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
