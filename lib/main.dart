import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'features/role_select_screen.dart';
import 'state/master_state.dart';
import 'state/player_state.dart';

void main() {
  runApp(const NavidadDeJordiApp());
}

class NavidadDeJordiApp extends StatelessWidget {
  const NavidadDeJordiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MasterState()),
        ChangeNotifierProvider(create: (_) => PlayerState()),
      ],
      child: MaterialApp(
        title: 'Navidad de Jordi',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const RoleSelectScreen(),
      ),
    );
  }
}
