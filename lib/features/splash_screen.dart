import 'dart:async';

import 'package:flutter/material.dart';

import 'role_select_screen.dart';

/// Pantalla de presentació que es mostra en obrir l'app: el logotip i el
/// nom de l'empresa amb un petit zoom d'entrada. Passats uns segons, canvia
/// sola a la pantalla principal.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Durada del zoom d'entrada.
  static const _zoomDuration = Duration(milliseconds: 1200);

  /// Temps total que es veu la pantalla abans de passar a la principal.
  static const _totalDuration = Duration(milliseconds: 3000);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _zoomDuration,
  );

  /// El zoom: comença una mica més petit i arriba a la mida normal.
  late final Animation<double> _scale = Tween<double>(begin: 0.8, end: 1.0)
      .animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );

  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(_totalDuration, _goToHome);
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RoleSelectScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 160,
                  height: 160,
                  semanticLabel: 'Logotip de Sopre Games',
                  // Si el fitxer no es troba, es mostra una icona de reserva.
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.emoji_events_outlined,
                    size: 120,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sopre Games',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
