import 'package:flutter/material.dart';

import 'pattern_background.dart';

class SplashLoadingScreen extends StatelessWidget {
  const SplashLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PatternBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) => Image.asset(
                'assets/images/splash_mark.png',
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fit: BoxFit.contain,
                color: scheme.onSecondaryContainer,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
