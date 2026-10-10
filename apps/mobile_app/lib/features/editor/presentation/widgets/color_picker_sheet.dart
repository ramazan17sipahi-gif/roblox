import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';

class ColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const ColorPickerSheet({super.key, this.initialColor = const Color(0xFFFF6A1A), required this.onColorSelected});

  static Future<Color?> show(BuildContext context, {Color initial = const Color(0xFFFF6A1A)}) {
    return showModalBottomSheet<Color>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ColorPickerSheet(
        initialColor: initial,
        onColorSelected: (c) => Navigator.pop(context, c),
      ),
    );
  }

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late Color _selected;
  final _hexController = TextEditingController();

  static const _swatches = [
    // Row 1 — Warm
    Color(0xFFFF6A1A), Color(0xFFFF8C3A), Color(0xFFFFAB40), Color(0xFFFFD740),
    Color(0xFFFF4081), Color(0xFFE040FB), Color(0xFFD500F9), Color(0xFFAA00FF),
    // Row 2 — Cool
    Color(0xFF00E5FF), Color(0xFF18FFFF), Color(0xFF00E676), Color(0xFF69F0AE),
    Color(0xFF448AFF), Color(0xFF536DFE), Color(0xFF7C4DFF), Color(0xFFB388FF),
    // Row 3 — Neutrals
    Color(0xFFFFFFFF), Color(0xFFE0E0E0), Color(0xFF9E9E9E), Color(0xFF616161),
    Color(0xFF424242), Color(0xFF212121), Color(0xFF000000), Color(0xFF3E2723),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
    _hexController.text = _colorToHex(_selected);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color c) => c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('Color Picker', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),

            // Selected color preview
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 48,
              decoration: BoxDecoration(
                color: _selected,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
              ),
              child: Center(
                child: Text(
                  '#${_colorToHex(_selected)}',
                  style: TextStyle(
                    color: _selected.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Color grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _swatches.map((c) => GestureDetector(
                onTap: () {
                  setState(() {
                    _selected = c;
                    _hexController.text = _colorToHex(c);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selected == c ? AppColors.primary : (c == Colors.white ? AppColors.outlineVariant.withOpacity(0.2) : Colors.transparent),
                      width: _selected == c ? 3 : 1,
                    ),
                    boxShadow: _selected == c
                        ? [BoxShadow(color: c.withOpacity(0.2), blurRadius: 8)]
                        : null,
                  ),
                  child: _selected == c
                      ? Icon(Icons.check, size: 16, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                      : null,
                ),
              )).toList(),
            ),
            SizedBox(height: 20),

            // HEX input
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _selected, borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
                    decoration: InputDecoration(
                      prefixText: '#',
                      prefixStyle: TextStyle(fontWeight: FontWeight.w800, color: AppColors.outlineVariant),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLowest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (hex) {
                      try {
                        final color = Color(int.parse('FF$hex', radix: 16));
                        setState(() => _selected = color);
                      } catch (e) { debugPrint('[color_picker_sheet] silent catch: $e'); }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            DSButton(
              label: AppLocalizations.of(context)!.colorPickerApply,
              onPressed: () => widget.onColorSelected(_selected),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
