import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../editor_state.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Result returned when the user confirms text styling.
class TextToolResult {
  final String text;
  final String font;
  final double fontSize;
  final Color color;
  final TextAlign align;

  const TextToolResult({
    required this.text,
    required this.font,
    required this.fontSize,
    required this.color,
    required this.align,
  });

  TextStyle toTextStyle() => EditorState.styleForTextFont(font, fontSize, color);
}

class TextToolSheet extends StatefulWidget {
  final String initialText;
  final String initialFont;
  final double initialFontSize;
  final Color initialColor;
  final TextAlign initialAlign;
  final bool isEditing;

  const TextToolSheet({
    super.key,
    this.initialText = '',
    this.initialFont = 'Default',
    this.initialFontSize = 24,
    this.initialColor = Colors.white,
    this.initialAlign = TextAlign.center,
    this.isEditing = false,
  });

  /// Opens the text composer and returns a [TextToolResult], or null if cancelled.
  static Future<TextToolResult?> show(
    BuildContext context, {
    String? initialText,
    String? initialFont,
    double? initialFontSize,
    Color? initialColor,
    TextAlign? initialAlign,
    bool isEditing = false,
    EditorState? editorState,
  }) {
    return showModalBottomSheet<TextToolResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: TextToolSheet(
          initialText: initialText ?? editorState?.textContent ?? '',
          initialFont: initialFont ?? editorState?.textFont ?? 'Default',
          initialFontSize: initialFontSize ?? editorState?.textSize ?? 24,
          initialColor: initialColor ?? editorState?.textColor ?? Colors.white,
          initialAlign: initialAlign ?? editorState?.textAlign ?? TextAlign.center,
          isEditing: isEditing,
        ),
      ),
    );
  }

  @override
  State<TextToolSheet> createState() => _TextToolSheetState();
}

class _TextToolSheetState extends State<TextToolSheet> {
  late TextEditingController _controller;
  late String _selectedFont;
  late double _fontSize;
  late Color _textColor;
  late TextAlign _textAlign;

  final _colors = [
    Colors.white,
    const Color(0xFFFF6A1A),
    const Color(0xFF00E5FF),
    const Color(0xFFFF4081),
    const Color(0xFF69F0AE),
    const Color(0xFFFFD740),
    const Color(0xFFB388FF),
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _selectedFont = widget.initialFont;
    _fontSize = widget.initialFontSize;
    _textColor = widget.initialColor;
    _textAlign = widget.initialAlign;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.text_fields, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.isEditing ? l.textToolTitle : l.editorAddText,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            style: EditorState.styleForTextFont(_selectedFont, _fontSize, _textColor),
            textAlign: _textAlign,
            decoration: InputDecoration(
              hintText: l.editorTextHint,
              hintStyle: TextStyle(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: EditorState.demoTexts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () {
                  _controller.text = EditorState.demoTexts[i];
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(EditorState.demoTexts[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l.textToolFont, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: EditorState.demoFonts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final font = EditorState.demoFonts[i];
                final isActive = font == _selectedFont;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFont = font),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: isActive ? null : Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      font,
                      style: TextStyle(
                        color: isActive ? Colors.white : AppColors.outlineVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(l.textToolSize, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('${_fontSize.toInt()}px', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
          Slider(
            value: _fontSize,
            min: 12,
            max: 72,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _fontSize = v),
          ),
          const SizedBox(height: 8),
          Text(l.textToolColor, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: _colors
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _textColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _textColor == c ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.2),
                            width: _textColor == c ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(l.textToolAlign, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              _alignBtn(Icons.format_align_left, TextAlign.left),
              _alignBtn(Icons.format_align_center, TextAlign.center),
              _alignBtn(Icons.format_align_right, TextAlign.right),
            ],
          ),
          const SizedBox(height: 24),
          DSButton(
            label: widget.isEditing ? l.commonSave : l.textToolAddText,
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(
                context,
                TextToolResult(
                  text: text,
                  font: _selectedFont,
                  fontSize: _fontSize,
                  color: _textColor,
                  align: _textAlign,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _alignBtn(IconData icon, TextAlign align) {
    final isActive = _textAlign == align;
    return GestureDetector(
      onTap: () => setState(() => _textAlign = align),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: isActive ? Colors.white : AppColors.outlineVariant),
      ),
    );
  }
}
