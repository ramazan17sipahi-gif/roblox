import 'package:flutter/material.dart';
import '../../editor/data/editor_route_params.dart';
import 'access_tier.dart';

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

  final AccessTier accessTier;

  /// Only populated for [TemplateType.classicClothing].
  final ClothingTemplateType? clothingTemplate;

  final String? category;
  final IconData icon;
  final Color accentColor;

  /// Pre-designed texture asset paths for "set" templates.
  /// These are local asset paths to 585×559 Roblox UV PNGs.
  final String? shirtAssetPath;
  final String? pantsAssetPath;
  final int likesCount;

  const TemplateItemModel({
    required this.templateId,
    required this.title,
    required this.type,
    this.thumbnailAsset,
    this.previewAsset,
    this.accessTier = AccessTier.free,
    this.clothingTemplate,
    this.category,
    this.icon = Icons.view_in_ar,
    this.accentColor = const Color(0xFFFF6A1A),
    this.shirtAssetPath,
    this.pantsAssetPath,
    this.likesCount = 0,
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

  bool get hasShirtTexture =>
      shirtAssetPath != null && shirtAssetPath!.isNotEmpty;
  bool get hasPantsTexture =>
      pantsAssetPath != null && pantsAssetPath!.isNotEmpty;
  bool get isFullSet => hasShirtTexture && hasPantsTexture;

  String get robloxClassLabel {
    if (isFullSet) return 'Set';
    return clothingTemplate?.robloxClassName ?? 'Shirt';
  }

  List<String> get previewActiveParts {
    if (isFullSet) {
      return const [
        'Torso',
        'Right Arm',
        'Left Arm',
        'Right Leg',
        'Left Leg',
      ];
    }
    return clothingTemplate?.activeParts ?? const [];
  }

  static String catalogTypeLabel(String? templateType) {
    switch (templateType) {
      case 'classic_pants':
        return 'Pants';
      case 'classic_tshirt':
        return 'T-Shirt';
      case 'classic_set':
        return 'Set';
      default:
        return 'Shirt';
    }
  }

  /// Build from a `clothing_templates` row (or explore's mapped copy).
  factory TemplateItemModel.fromClothingTemplateRow(Map<String, dynamic> row) {
    final type = row['template_type'] as String? ?? '';
    return TemplateItemModel(
      templateId: (row['id'] ?? '').toString(),
      title: (row['name'] as String?) ?? 'Untitled',
      type: TemplateType.classicClothing,
      clothingTemplate: switch (type) {
        'classic_pants' => ClothingTemplateType.blankPants,
        'classic_tshirt' => ClothingTemplateType.blankTShirt,
        _ => ClothingTemplateType.blankShirt,
      },
      icon: Icons.checkroom,
      accentColor: const Color(0xFFFF793A),
      shirtAssetPath: row['shirt_texture_url'] as String?,
      pantsAssetPath: row['pants_texture_url'] as String?,
      thumbnailAsset: (row['preview_front_url'] as String?) ??
          (row['shirt_texture_url'] as String?) ??
          (row['thumbnail_url'] as String?),
      previewAsset: row['preview_front_url'] as String?,
      accessTier: AccessTier.fromRow(row),
      likesCount: _parseLikes(row['likes_count']),
    );
  }

  static int _parseLikes(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}
