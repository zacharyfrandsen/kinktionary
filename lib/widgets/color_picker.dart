import 'package:flutter/material.dart';

const _presets = <Color>[
  Color(0xFFD6A1FF),
  Color(0xFFF6C9E6),
  Color(0xFFF5C77E),
  Color(0xFFFF6B8B),
  Color(0xFFFF8A5B),
  Color(0xFF7BE0A4),
  Color(0xFF5EC8F2),
  Color(0xFF7C8CFF),
  Color(0xFFB04CFF),
  Color(0xFF3A1F5C),
  Color(0xFF14324A),
  Color(0xFF4A1633),
];

String colorToHex(Color color) =>
    color.toARGB32().toRadixString(16).substring(2).toUpperCase();

Color? colorFromHex(String input) {
  final hex = input.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex, radix: 16));
}

/// Bottom sheet with hue / saturation / brightness sliders, a hex field and presets.
Future<Color?> showColorPicker(
  BuildContext context, {
  required Color initial,
  String title = 'Pick a colour',
}) {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ColorPickerSheet(initial: initial, title: title),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  final Color initial;
  final String title;
  const _ColorPickerSheet({required this.initial, required this.title});

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final TextEditingController _hex =
      TextEditingController(text: colorToHex(widget.initial));

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set(HSVColor value) {
    setState(() => _hsv = value);
    _hex.text = colorToHex(value.toColor());
  }

  Widget _slider({
    required String label,
    required double value,
    required double max,
    required List<Color> colors,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(label)),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(colors: colors),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 12,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(value: value, max: max, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
          ),
          const SizedBox(height: 8),
          _slider(
            label: 'Hue',
            value: _hsv.hue,
            max: 360,
            colors: [
              for (var h = 0; h <= 360; h += 60)
                HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
            ],
            onChanged: (v) => _set(_hsv.withHue(v)),
          ),
          _slider(
            label: 'Saturation',
            value: _hsv.saturation,
            max: 1,
            colors: [
              _hsv.withSaturation(0).toColor(),
              _hsv.withSaturation(1).toColor(),
            ],
            onChanged: (v) => _set(_hsv.withSaturation(v)),
          ),
          _slider(
            label: 'Brightness',
            value: _hsv.value,
            max: 1,
            colors: [
              _hsv.withValue(0).toColor(),
              _hsv.withValue(1).toColor(),
            ],
            onChanged: (v) => _set(_hsv.withValue(v)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hex,
            maxLength: 7,
            autocorrect: false,
            decoration: const InputDecoration(
              prefixText: '#',
              labelText: 'Hex',
              counterText: '',
            ),
            onChanged: (value) {
              final parsed = colorFromHex(value);
              if (parsed != null) {
                setState(() => _hsv = HSVColor.fromColor(parsed));
              }
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in _presets)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    _set(HSVColor.fromColor(preset));
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: preset,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, color),
                  child: const Text('Use colour'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// List row showing a colour swatch that opens the picker.
class ColorTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? color;
  final Color fallback;
  final ValueChanged<Color> onChanged;
  final VoidCallback? onReset;

  const ColorTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.color,
    required this.fallback,
    required this.onChanged,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final shown = color ?? fallback;
    return ListTile(
      title: Text(title),
      subtitle: Text(
          subtitle ?? (color == null ? 'Default' : '#${colorToHex(shown)}')),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: shown,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
      ),
      trailing: color != null && onReset != null
          ? IconButton(
              tooltip: 'Reset to default',
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
            )
          : null,
      onTap: () async {
        final picked =
            await showColorPicker(context, initial: shown, title: title);
        if (picked != null) onChanged(picked);
      },
    );
  }
}
