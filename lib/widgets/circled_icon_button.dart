import 'package:flutter/material.dart';

/// A round, outlined icon button.
///
/// The way out of a screen gets the same weight as the completion circles in
/// the learning paths, so it reads as a control at a glance instead of a faint
/// glyph in the corner of the app bar.
class CircledIconButton extends StatelessWidget {
  const CircledIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 19,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.75), width: 1.5),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
    );
  }
}
