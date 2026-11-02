import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data_store.dart';

/// Shown while the store loads: the Aftercare mark inside a wobbly ring that
/// fills as the data arrives, with the percentage it has reached.
///
/// It is only on screen for as long as loading takes, so it never holds the app
/// back; a fast load is a blink, a slow one is a ring you can watch fill.
class SplashLoadingScreen extends StatelessWidget {
  const SplashLoadingScreen({super.key, required this.store});

  final DataStore store;

  static const double _diameter = 244;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ValueListenableBuilder<double>(
            valueListenable: store.loadProgress,
            builder: (context, progress, _) => SizedBox(
              width: _diameter,
              height: _diameter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WobblyRing(
                        progress: progress.clamp(0.0, 1.0),
                        track: scheme.surfaceContainerHighest,
                        fill: scheme.secondary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/aftercare_logo.png',
                        width: 104,
                        color: scheme.secondary,
                        colorBlendMode: BlendMode.srcIn,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring around the mark: a scalloped circle, the way a hand draws one, with
/// its filled part sweeping from the top.
class _WobblyRing extends CustomPainter {
  const _WobblyRing({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  static const double _stroke = 9;

  /// One lap, starting at the top: a circle whose radius ripples in a counted
  /// number of lobes, with two smaller harmonics so no two lobes match exactly.
  static Path _lap(Size size) {
    final centre = size.center(Offset.zero);
    final base = size.shortestSide / 2 - _stroke / 2 - 2;
    final path = Path();
    const steps = 1440;
    for (var i = 0; i <= steps; i++) {
      final angle = i / steps * math.pi * 2;
      final radius = base *
          (1 +
              0.026 * math.sin(16 * angle) +
              0.010 * math.sin(5 * angle + 1.1) +
              0.005 * math.sin(27 * angle + 2.6));
      final point = centre +
          Offset(
            math.cos(angle - math.pi / 2),
            math.sin(angle - math.pi / 2),
          ) *
              radius;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lap = _lap(size);
    canvas.drawPath(
      lap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = track,
    );
    if (progress <= 0) return;
    final metric = lap.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = fill,
    );
  }

  @override
  bool shouldRepaint(_WobblyRing oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.fill != fill;
}
