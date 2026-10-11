import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../network/connection_info.dart';
import '../../state/player_state.dart';
import 'player_lobby_screen.dart';
import 'qr_scan_screen.dart';

class PlayerJoinScreen extends StatefulWidget {
  const PlayerJoinScreen({super.key});

  @override
  State<PlayerJoinScreen> createState() => _PlayerJoinScreenState();
}

class _PlayerJoinScreenState extends State<PlayerJoinScreen> {
  final _nameController = TextEditingController();
  final _manualAddressController = TextEditingController();
  final _manualCodeController = TextEditingController();

  ConnectionInfo? _connectionInfo;
  bool _showManualForm = false;
  bool _joining = false;

  Future<void> _scanQr() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (raw == null) return;
    final info = ConnectionInfo.tryParse(raw);
    if (info == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aquest codi QR no és vàlid.")),
      );
      return;
    }
    setState(() => _connectionInfo = info);
  }

  void _useManualEntry() {
    final address = _manualAddressController.text.trim();
    final code = _manualCodeController.text.trim().toUpperCase();
    final parts = address.split(':');
    if (parts.length != 2 || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Escriu l'adreça com a 192.168.1.5:53421"),
        ),
      );
      return;
    }
    final port = int.tryParse(parts[1]);
    if (port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("El port no és vàlid.")),
      );
      return;
    }
    setState(() {
      _connectionInfo = ConnectionInfo(
        sessionId: '',
        sessionName: '',
        host: parts[0],
        port: port,
        joinCode: code,
      );
    });
  }

  Future<void> _join() async {
    final info = _connectionInfo;
    final name = _nameController.text.trim();
    if (info == null || name.isEmpty) return;
    setState(() => _joining = true);
    final playerState = context.read<PlayerState>();
    await playerState.joinSession(connectionInfo: info, playerName: name);
    if (!mounted) return;
    setState(() => _joining = false);
    if (playerState.joinRejectedReason != null) {
      final reason = playerState.joinRejectedReason;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          reason == 'locked'
              ? "El màster ha tancat la sessió a noves incorporacions."
              : "El codi no és correcte.",
        ),
      ));
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PlayerLobbyScreen()),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _manualAddressController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Unir-se a la partida")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_connectionInfo == null) ...[
            FilledButton.icon(
              onPressed: _scanQr,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Escanejar el QR del màster"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  setState(() => _showManualForm = !_showManualForm),
              child: const Text("No puc escanejar, introduir-ho a mà"),
            ),
            if (_showManualForm) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _manualAddressController,
                decoration: const InputDecoration(
                  labelText: "Adreça (per exemple 192.168.1.5:53421)",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manualCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: "Codi de la partida"),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _useManualEntry,
                child: const Text("Continuar"),
              ),
            ],
          ] else ...[
            Text(
              "Connexió preparada.",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "El teu nom"),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _joining ? null : _join,
              child: _joining
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Unir-me a la partida"),
            ),
            TextButton(
              onPressed: () => setState(() => _connectionInfo = null),
              child: const Text("Tornar a intentar-ho"),
            ),
          ],
        ],
      ),
    );
  }
}
