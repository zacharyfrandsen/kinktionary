import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A horizontal strip of chips that a mouse can drag.
///
/// Flutter keeps a mouse drag for selecting text, so on the web a sideways list
/// gives a desktop visitor no way to reach what is past the right edge: the
/// wheel is vertical and the drag does nothing. Letting the mouse drag the row,
/// and reading a vertical wheel over it as "sideways", makes the strip behave
/// the way a website's does.
class ChipRail extends StatefulWidget {
  const ChipRail({
    super.key,
    required this.children,
    this.height,
    this.padding,
  });

  final List<Widget> children;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  State<ChipRail> createState() => _ChipRailState();
}

class _ChipRailState extends State<ChipRail> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_controller.hasClients) return;
    final delta = event.scrollDelta.dy + event.scrollDelta.dx;
    if (delta == 0) return;
    final position = _controller.position;
    _controller.jumpTo(
      (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
          },
        ),
        child: SizedBox(
          height: widget.height,
          child: ListView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}
