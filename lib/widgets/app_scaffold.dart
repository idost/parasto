import 'package:flutter/material.dart';
import 'package:myna/widgets/mini_player.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;
  
  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomSheet: const MiniPlayer(),
    );
  }
}
