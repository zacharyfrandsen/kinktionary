import 'package:flutter/material.dart';

/// Tiled wallpaper shown behind every screen.
class PatternBackground extends StatefulWidget {
  final Widget child;
  const PatternBackground({super.key, required this.child});

  @override
  State<PatternBackground> createState() => _PatternBackgroundState();
}

class _PatternBackgroundState extends State<PatternBackground> {
  double _scrollPixels = 0;

  static const AssetImage _wallpaper =
      AssetImage('assets/images/background_items.webp');
  static const AssetImage _lightTile =
      AssetImage('assets/images/pattern_tile.png');

  /// Icon colour on light backgrounds (black at ~7%).
  static const Color lightInk = Color(0x12000000);

  /// Shows about three unboxed motifs across a phone-width viewport.
  static const double wallpaperScale = 2.6;
  static const double lightTileScale = 3.0;
  static const double _wallpaperHeight = 2550;
  static const double _lightTileHeight = 1200;

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.pixels != _scrollPixels) {
      setState(() => _scrollPixels = notification.metrics.pixels);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scale = dark ? wallpaperScale : lightTileScale;
    final tileHeight =
        (dark ? _wallpaperHeight : _lightTileHeight) / scale;
    final offset = _scrollPixels % tileHeight;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layerHeight = constraints.maxHeight + tileHeight;
                  return OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: constraints.maxWidth,
                    maxWidth: constraints.maxWidth,
                    minHeight: layerHeight,
                    maxHeight: layerHeight,
                    child: Transform.translate(
                      key: const ValueKey('scrolling-wallpaper'),
                      offset: Offset(0, -offset),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          image: DecorationImage(
                            image: dark ? _wallpaper : _lightTile,
                            repeat: ImageRepeat.repeat,
                            alignment: dark ? Alignment.center : Alignment.topLeft,
                            fit: dark ? BoxFit.none : BoxFit.scaleDown,
                            scale: scale,
                            colorFilter: dark
                                ? null
                                : const ColorFilter.mode(
                                    lightInk, BlendMode.srcIn),
                          ),
                        ),
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: layerHeight,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// A Scaffold whose background is the wallpaper. Use it instead of Scaffold.
class PatternScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  const PatternScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return PatternBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
