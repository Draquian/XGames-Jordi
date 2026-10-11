import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/master_state.dart';
import 'master_lobby_screen.dart';

class MasterHomeScreen extends StatefulWidget {
  const MasterHomeScreen({super.key});

  @override
  State<MasterHomeScreen> createState() => _MasterHomeScreenState();
}

class _MasterHomeScreenState extends State<MasterHomeScreen> {
  final _nameController = TextEditingController(text: "Navidad de Jordi");
  bool _checkingResume = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkResumable());
  }

  Future<void> _checkResumable() async {
    final master = context.read<MasterState>();
    final resumed = await master.tryResumeSession();
    if (!mounted) return;
    if (resumed) {
      _goToLobby();
      return;
    }
    setState(() => _checkingResume = false);
  }

  void _goToLobby() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MasterLobbyScreen()),
    );
  }

  Future<void> _createSession() async {
    final master = context.read<MasterState>();
    final ok = await master.createSession(_nameController.text);
    if (!mounted) return;
    if (ok) {
      _goToLobby();
      return;
    }
    if (master.startError == 'no_wifi') {
      _showNoWifiDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No s'ha pogut crear la sessió.")),
      );
    }
  }

  void _showNoWifiDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cal una xarxa WiFi"),
        content: const Text(
          "Aquest mòbil no està connectat a cap xarxa WiFi.\n\n"
          "Si al lloc de la festa hi ha un router (per exemple, el de "
          "casa), connecta't a la seva xarxa des dels Ajustos.\n\n"
          "Si no n'hi ha cap, activa el 'Punt d'accés personal' del teu "
          "mòbil des dels Ajustos i torna aquí.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("D'acord"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final master = context.watch<MasterState>();

    if (_checkingResume) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Nova sessió")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Nom de la partida"),
            const SizedBox(height: 8),
            TextField(controller: _nameController),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: master.isStarting ? null : _createSession,
              child: master.isStarting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Crear sessió i generar QR"),
            ),
          ],
        ),
      ),
    );
  }
}
