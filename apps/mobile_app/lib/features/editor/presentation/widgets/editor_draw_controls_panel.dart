import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../editor_tool_constants.dart';

/// Brush/color/size controls for the active 2D drawing tool.
class EditorDrawControlsPanel extends StatelessWidget {
  final int activeDrawTool;
  final List<Color> colorPalette;
  final ValueChanged<Color> onColorSelected;
  final Color? selectedColor;
  final bool showColorRow;
  final double brushSize;
  final ValueChanged<double> onBrushSizeChanged;
  final double brushOpacity;
  final ValueChanged<double> onBrushOpacityChanged;
  final Widget? gradientControls;
  final Widget? shapeControls;

  const EditorDrawControlsPanel({
    super.key,
    required this.activeDrawTool,
    required this.colorPalette,
    required this.onColorSelected,
    this.selectedColor,
    this.showColorRow = true,
    required this.brushSize,
    required this.onBrushSizeChanged,
    required this.brushOpacity,
    required this.onBrushOpacityChanged,
    this.gradientControls,
    this.shapeControls,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final showSliders = activeDrawTool == EditorDrawToolIndex.brush ||
        activeDrawTool == EditorDrawToolIndex.eraser ||
        activeDrawTool == EditorDrawToolIndex.shape;
    if (!showColorRow && !showSliders && gradientControls == null && shapeControls == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: bottomPad > 0 ? 4 : 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showColorRow) ...[
            Text(
              'Fırça rengi',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.outlineVariant),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 26,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: colorPalette.length,
                separatorBuilder: (_, __) => const SizedBox(width: 5),
                itemBuilder: (_, i) {
                  final c = colorPalette[i];
                  final isSelected = selectedColor != null && c.toARGB32() == selectedColor!.toARGB32();
                  return GestureDetector(
                    onTap: () => onColorSelected(c),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (c == const Color(0xFFFFFFFF)
                                  ? AppColors.outlineVariant.withValues(alpha: 0.3)
                                  : c.withValues(alpha: 0.5)),
                          width: isSelected ? 2.5 : 2,
                        ),
                        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.2), blurRadius: 4)],
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 12, color: c.computeLuminance() > 0.55 ? Colors.black87 : Colors.white)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
          if (showSliders) ...[
            if (showColorRow) const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Boyut',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.outlineVariant),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.outlineVariant.withValues(alpha: 0.15),
                      thumbColor: AppColors.primary,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(value: brushSize, onChanged: onBrushSizeChanged),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Opaklık',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.outlineVariant),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.outlineVariant.withValues(alpha: 0.15),
                      thumbColor: AppColors.primary,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(value: brushOpacity, onChanged: onBrushOpacityChanged),
                  ),
                ),
              ],
            ),
          ],
          if (activeDrawTool == EditorDrawToolIndex.gradient && gradientControls != null) gradientControls!,
          if (activeDrawTool == EditorDrawToolIndex.shape && shapeControls != null) shapeControls!,
        ],
      ),
    );
  }
}
