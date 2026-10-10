import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../editor_state.dart';
import '../../../../l10n/generated/app_localizations.dart';

class DrawToolControls extends StatefulWidget {
  final EditorState editorState;
  const DrawToolControls({super.key, required this.editorState});

  @override
  State<DrawToolControls> createState() => _DrawToolControlsState();
}

class _DrawToolControlsState extends State<DrawToolControls> {
  late double _brushSize;
  late double _brushOpacity;
  late Color _brushColor;
  late bool _isErasing;

  final _colors = [
    const Color(0xFFFF6A1A),
    const Color(0xFFFF4081),
    const Color(0xFF00E5FF),
    const Color(0xFF69F0AE),
    const Color(0xFFFFD740),
    const Color(0xFFB388FF),
    Colors.white,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _brushSize = widget.editorState.brushSize;
    _brushOpacity = widget.editorState.brushOpacity;
    _brushColor = widget.editorState.brushColor;
    _isErasing = widget.editorState.isErasing;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.draw, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Draw Tool', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              // Eraser toggle
              GestureDetector(
                onTap: () {
                  setState(() => _isErasing = !_isErasing);
                  widget.editorState.isErasing = _isErasing;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isErasing ? AppColors.primary : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    border: _isErasing ? null : Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_isErasing ? Icons.auto_fix_high : Icons.auto_fix_off, size: 14, color: _isErasing ? Colors.white : AppColors.outlineVariant),
                      SizedBox(width: 4),
                      Text('Eraser', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _isErasing ? Colors.white : AppColors.outlineVariant)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 24),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brush Size
              Row(
                children: [
                  Text('Brush Size', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text('${(_brushSize * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
              Slider(
                value: _brushSize,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _brushSize = val);
                  widget.editorState.setBrushSize(val);
                },
              ),

              // Brush Size preview
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 8 + _brushSize * 40,
                  height: 8 + _brushSize * 40,
                  decoration: BoxDecoration(
                    color: _isErasing ? AppColors.outlineVariant : _brushColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Opacity
              Row(
                children: [
                  Text('Opacity', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text('${(_brushOpacity * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
              Slider(
                value: _brushOpacity,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _brushOpacity = val);
                  widget.editorState.setBrushOpacity(val);
                },
              ),
              const SizedBox(height: 8),

              // Color
              Text('Brush Color', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: _colors.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _brushColor = c);
                      widget.editorState.setBrushColor(c);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _brushColor == c ? AppColors.primary : AppColors.outlineVariant.withOpacity(0.2),
                          width: _brushColor == c ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
              DSButton(
                label: _isErasing ? 'Start Erasing' : 'Start Drawing',
                icon: _isErasing ? Icons.auto_fix_high : Icons.draw,
                onPressed: () {
                  widget.editorState.pushAction(_isErasing ? 'Eraser active' : 'Draw tool active');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isErasing ? 'Eraser mode active' : 'Draw mode active — drag on canvas'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
