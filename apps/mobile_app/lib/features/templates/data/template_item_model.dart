import 'package:flutter/material.dart';
import '../../editor/data/editor_route_params.dart';

/// Template type for the creation flow.
enum TemplateType {
  /// Classic clothing creation flow → EditorMode.classicClothingBlankStart
  classicClothing,
}

/// Unified data model for the template preview funnel.
///
/// All entry points (Home quick-actions, Templates tab) produce a
/// [TemplateItemModel] that is passed to `/template-preview` and
/// subsequently consumed by the editor.
class TemplateItemModel {
  final String templateId;
  final String title;
  final TemplateType type;

  /// URL or local asset path for card thumbnails.
  final String? thumbnailAsset;

  /// Larger preview image for the preview page hero area.
  final String? previewAsset;

  final bool isPro;

  /// Only populated for [TemplateType.classicClothing].
  final ClothingTemplateType? clothingTemplate;

  final String? category;
  final IconData icon;
  final Color accentColor;

  /// Pre-designed texture asset paths for "set" templates.
  /// These are local asset paths to 585×559 Roblox UV PNGs.
  final String? shirtAssetPath;
  final String? pantsAssetPath;

  const TemplateItemModel({
    required this.templateId,
    required this.title,
    required this.type,
    this.thumbnailAsset,
    this.previewAsset,
    this.isPro = false,
    this.clothingTemplate,
    this.category,
    this.icon = Icons.view_in_ar,
    this.accentColor = const Color(0xFFFF6A1A),
    this.shirtAssetPath,
    this.pantsAssetPath,
  });

  /// Deterministic mode resolution.
  EditorMode get editorMode => EditorMode.classicClothingBlankStart;

  /// Build typed [EditorRouteParams] from this template.
  EditorRouteParams toEditorParams() {
    return EditorRouteParams(
      mode: editorMode,
      clothingTemplate: clothingTemplate,
      shirtAssetPath: shirtAssetPath,
      pantsAssetPath: pantsAssetPath,
    );
  }

  /// Whether [thumbnailAsset] looks like a network URL.
  bool get isThumbnailNetwork =>
      thumbnailAsset != null &&
      (thumbnailAsset!.startsWith('http://') ||
          thumbnailAsset!.startsWith('https://'));

  /// Whether [previewAsset] looks like a network URL.
  bool get isPreviewNetwork =>
      previewAsset != null &&
      (previewAsset!.startsWith('http://') ||
          previewAsset!.startsWith('https://'));

  /// Best available image: previewAsset > thumbnailAsset > null (icon fallback).
  String? get bestImageAsset => previewAsset ?? thumbnailAsset;

  /// Whether the best image is a network resource.
  bool get isBestImageNetwork {
    final best = bestImageAsset;
    if (best == null) return false;
    return best.startsWith('http://') || best.startsWith('https://');
  }

  /// Type display name for badges and headers.
  String get typeDisplayName => 'Classic Clothing';
}
