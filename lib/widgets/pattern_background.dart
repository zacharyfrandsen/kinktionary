import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../appearance.dart';

/// Wallpaper shown behind every screen.
///
/// There is exactly one of these, mounted above the app's navigator, so the
/// pattern is one continuous endless field: it drifts with whatever list you
/// scroll, and keeps its place when you move between screens, so the backdrop
/// carries on rather than restarting as a picture per page.
class PatternBackground extends StatefulWidget {
  final Widget child;
  const PatternBackground({super.key, required this.child});

  /// Image pixels per logical pixel for the tile on a roomy window.
  static const double wallpaperScale = 2200 / 1276;

  /// Below this window width the tile is drawn [phoneShrink] times smaller.
  ///
  /// An icon is a fixed size in logical pixels, so on a phone it covers a much
  /// larger share of the view than it does on a monitor, and the field reads
  /// as a few big shapes with room to spare. Drawing the tile smaller there
  /// brings both the icons and the gaps between them down together.
  static const double phoneWidth = 700;
  static const double phoneShrink = 1.32;

  static double scaleForWidth(double width) =>
      width < phoneWidth ? wallpaperScale * phoneShrink : wallpaperScale;

  @override
  State<PatternBackground> createState() => _PatternBackgroundState();
}

class _PatternBackgroundState extends State<PatternBackground> {
  /// A seamless tile: the artwork is wrapped, so motifs that cross the edge
  /// continue on the other side instead of being sliced by the repeat.
  static const AssetImage _icons =
      AssetImage('assets/images/background_icons_seamless.png');

  static final Listenable _wallpaperChanged = Listenable.merge([
    AppAppearance.gradient,
    AppAppearance.icons,
    wallpaperIntensity,
    wallpaperTravel,
  ]);

  ui.Image? _tile;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null) return;
    final stream = _icons.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) {
        if (mounted) setState(() => _tile = info.image);
      },
      onError: (_, __) {},
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    super.dispose();
  }

  /// Any vertical list in the app drives the wallpaper, wherever it sits, so a
  /// swipe on the feed, the glossary, a path or a settings page all move the
  /// same surface and it carries on from where the last one left it.
  Widget _travelWithScroll(Widget child) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification &&
              notification.metrics.axis == Axis.vertical) {
            final delta = notification.scrollDelta;
            if (delta != null && delta != 0) {
              wallpaperTravel.value += delta;
            }
          }
          return false;
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: ListenableBuilder(
              listenable: _wallpaperChanged,
              builder: (context, _) {
                final gradient = AppAppearance.gradient.value;
                final custom = AppAppearance.icons.value;
                final intensity = wallpaperIntensity.value.clamp(0.0, 1.0);
                final tint = (custom ?? Colors.white).withValues(
                    alpha: (custom == null ? 0.25 : 0.6) * intensity);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: gradient == null ? surface : null,
                    gradient: gradient?.toLinear(),
                  ),
                  child: CustomPaint(
                    painter: _WallpaperPainter(
                      image: _tile,
                      tint: tint,
                      scale: PatternBackground.scaleForWidth(
                          MediaQuery.sizeOf(context).width),
                      travel: wallpaperTravel.value,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _travelWithScroll(widget.child),
      ],
    );
  }
}

/// Tiles the wallpaper in one shader draw.
///
/// A repeated [DecorationImage] paints each copy as its own rectangle at a
/// fractional scale, which leaves a hairline between copies — a visible stitch
/// running through any motif that crosses the tile edge. A repeated shader
/// samples one texture continuously instead, so the copies join with no seam.
class _WallpaperPainter extends CustomPainter {
  const _WallpaperPainter({
    required this.image,
    required this.tint,
    required this.scale,
    required this.travel,
  });

  final ui.Image? image;
  final Color tint;
  final double scale;

  /// Logical pixels the wallpaper has been scrolled. Kept modulo the tile
  /// height, so a long session cannot lose precision.
  final double travel;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null || size.isEmpty) return;

    // A shader matrix maps image pixels into logical pixels, so it is the
    // inverse of the image's on-screen scale. Shift by half the leftover width
    // so the first copy is centred on the width and starts at the top edge.
    final dx = (size.width - image.width / scale) / 2;
    final tileHeight = image.height / scale;
    final dy = -(travel % tileHeight);
    final s = 1 / scale;
    final matrix = Float64List.fromList(<double>[
      s, 0, 0, 0, //
      0, s, 0, 0, //
      0, 0, 1, 0, //
      dx, dy, 0, 1, //
    ]);

    final paint = Paint()
      ..shader = ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        matrix,
        filterQuality: FilterQuality.medium,
      )
      ..colorFilter = ColorFilter.mode(tint, BlendMode.srcIn);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) =>
      old.image != image ||
      old.tint != tint ||
      old.scale != scale ||
      old.travel != travel;
}

/// A Scaffold that lets the wallpaper show through. Use it instead of
/// Scaffold; the wallpaper itself is mounted once, above the navigator.
class PatternScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  /// Caps the whole screen to a readable column on wide windows, so a definition
  /// or a settings list does not run from edge to edge on a monitor. The home
  /// shell lays out its own columns, so it turns this off.
  final bool constrainWidth;

  static const double readableWidth = 760;

  const PatternScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.constrainWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
    if (!constrainWidth) return scaffold;
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth <= readableWidth
          ? scaffold
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: readableWidth),
                child: scaffold,
              ),
            ),
    );
  }
}
