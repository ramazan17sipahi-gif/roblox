import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../editor_state.dart';
import '../../../../l10n/generated/app_localizations.dart';

class TextToolSheet extends StatefulWidget {
  final EditorState editorState;
  const TextToolSheet({super.key, required this.editorState});

  static Future<void> show(BuildContext context, EditorState state) {
    return showModalBottomSheet(
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
        child: TextToolSheet(editorState: state),
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
    _controller = TextEditingController(text: widget.editorState.textContent);
    _selectedFont = widget.editorState.textFont;
    _fontSize = widget.editorState.textSize;
    _textColor = widget.editorState.textColor;
    _textAlign = widget.editorState.textAlign;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.text_fields, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Add Text', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),

          // Text input
          TextField(
            controller: _controller,
            style: TextStyle(fontSize: _fontSize, color: _textColor, fontWeight: FontWeight.bold),
            textAlign: _textAlign,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.editorTextHint,
              hintStyle: TextStyle(color: AppColors.outlineVariant.withOpacity(0.2)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),

          // Quick text suggestions
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

          // Font selector
          Text('Font', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                      border: isActive ? null : Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
                    ),
                    child: Text(font, style: TextStyle(color: isActive ? Colors.white : AppColors.outlineVariant, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),

          // Size slider
          Row(
            children: [
              Text('Size', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
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

          // Color row
          const SizedBox(height: 8),
          Text('Color', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: _colors.map((c) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => setState(() => _textColor = c),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _textColor == c ? AppColors.primary : AppColors.outlineVariant.withOpacity(0.2),
                      width: _textColor == c ? 3 : 1,
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),

          // Alignment
          Row(
            children: [
              Text('Align', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              _alignBtn(Icons.format_align_left, TextAlign.left),
              _alignBtn(Icons.format_align_center, TextAlign.center),
              _alignBtn(Icons.format_align_right, TextAlign.right),
            ],
          ),
          const SizedBox(height: 24),

          // Apply
          DSButton(
            label: AppLocalizations.of(context)!.textToolAddText,
            onPressed: () {
              widget.editorState.setTextContent(_controller.text);
              widget.editorState.setTextSize(_fontSize);
              widget.editorState.setTextColor(_textColor);
              widget.editorState.setTextFont(_selectedFont);
              widget.editorState.setTextAlign(_textAlign);
              widget.editorState.pushAction('Added text: "${_controller.text}"');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Text "${_controller.text}" applied'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)),
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
        width: 36, height: 36,
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
