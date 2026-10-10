import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/editor_route_params.dart';
import '../widgets/classic_clothing_selector.dart';
import '../widgets/classic_clothing_editor.dart';

class EditorShellPage extends StatefulWidget {
  final EditorMode mode;
  final ClothingTemplateType? clothingTemplate;

  /// Pre-designed texture asset paths for set templates.
  final String? shirtAssetPath;
  final String? pantsAssetPath;
  final String? projectId;

  const EditorShellPage({
    super.key,
    this.mode = EditorMode.classicClothingBlankStart,
    this.clothingTemplate,
    this.shirtAssetPath,
    this.pantsAssetPath,
    this.projectId,
  });

  @override
  State<EditorShellPage> createState() => _EditorShellPageState();
}

class _EditorShellPageState extends State<EditorShellPage> {
  // Classic clothing state
  ClothingTemplateType? _selectedClothingTemplate;
  String? _shirtAssetPath;
  String? _pantsAssetPath;

  @override
  void initState() {
    super.initState();
    _selectedClothingTemplate = widget.clothingTemplate;
    _shirtAssetPath = widget.shirtAssetPath;
    _pantsAssetPath = widget.pantsAssetPath;
  }

  void _handleSelectorResult(ClothingSelectorResult result) {
    setState(() {
      if (result.blankType != null) {
        // Blank template selected (T-Shirt, Shirt, Pants)
        _selectedClothingTemplate = result.blankType;
        _shirtAssetPath = null;
        _pantsAssetPath = null;
      } else if (result.preDesigned != null) {
        // Pre-designed template selected
        final t = result.preDesigned!;
        _selectedClothingTemplate = t.clothingTemplate;
        _shirtAssetPath = t.shirtAssetPath;
        _pantsAssetPath = t.pantsAssetPath;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── Classic Clothing Editor (after template selected) ──
    if (_selectedClothingTemplate != null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: ClassicClothingEditor(
            template: _selectedClothingTemplate!,
            shirtAssetPath: _shirtAssetPath,
            pantsAssetPath: _pantsAssetPath,
            projectId: widget.projectId,
          ),
        ),
      );
    }

    // ── Classic Clothing Selector (no template chosen yet) ──
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ClassicClothingSelector(
          onSelect: _handleSelectorResult,
          onClose: () => context.pop(),
        ),
      ),
    );
  }
}
