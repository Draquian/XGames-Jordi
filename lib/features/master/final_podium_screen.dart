import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/master_state.dart';
import '../shared/podium_view.dart';

class FinalPodiumScreen extends StatelessWidget {
  const FinalPodiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final master = context.watch<MasterState>();
    return Scaffold(
      appBar: AppBar(title: const Text("Partida finalitzada")),
      body: PodiumView(standings: master.finalStandings),
    );
  }
}
