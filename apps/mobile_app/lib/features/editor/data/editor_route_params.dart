import 'package:flutter/material.dart';

/// Editor entry modes — defines how the editor shell initializes.
///
/// All navigation to `/editor` must use [EditorRouteParams] with one of these modes.
/// This eliminates raw-string typo risk and ensures typed contracts.
enum EditorMode {
  /// Opened from "Create Classic Clothing" card — selector first, then 2D UV editor.
  /// Classic clothing uses 2D texture templates (585×559 for Shirts, 585×559 for Pants).
  /// Applied via Shirt/Pants/ShirtGraphic instances, NOT via caging system.
  classicClothingBlankStart,
}

/// Classic clothing blank template types.
/// Reference: https://create.roblox.com/docs/art/classic-clothing
///
/// Classic clothing is fundamentally different from layered clothing:
/// - Classic clothing: 2D images wrapped onto the R15 body via UV mapping
/// - Layered clothing: 3D cage meshes (inner+outer) that deform over the body
///
/// UV Template sizes (official):
/// - Shirts: 585 × 559 pixels
/// - Pants: 585 × 559 pixels
/// - T-Shirts: 128 × 128 pixels (applied to front torso only)
enum ClothingTemplateType {
  blankPants,
  blankShirt,
  blankTShirt,
}

/// Extension helpers for [ClothingTemplateType].
extension ClothingTemplateTypeX on ClothingTemplateType {
  String get displayName {
    switch (this) {
      case ClothingTemplateType.blankPants:
        return 'Boş Pantolon';
      case ClothingTemplateType.blankShirt:
        return 'Boş Gömlek';
      case ClothingTemplateType.blankTShirt:
        return 'Boş Tişört';
    }
  }

  /// Subtitle describing what this template covers.
  String get subtitle {
    switch (this) {
      case ClothingTemplateType.blankPants:
        return '585×559 UV template';
      case ClothingTemplateType.blankShirt:
        return '585×559 UV template';
      case ClothingTemplateType.blankTShirt:
        return '128×128 front decal';
    }
  }

  /// Which UV parts are active for this template.
  /// Based on official Roblox Classic Clothing UV layout.
  /// Reference: https://create.roblox.com/docs/art/classic-clothing
  ///
  /// Shirt (585×559): Torso (R, Front, L, Back, Up, Down) + Right Arm (L,B,R,F,D) + Left Arm (F,L,B,R,D)
  /// Pants (585×559): Torso (R, Front, L, Back, Up, Down) + Right Leg (L,B,R,F,D) + Left Leg (F,L,B,R,D)
  /// T-Shirt (128×128): Front Decal only
  List<String> get activeParts {
    switch (this) {
      case ClothingTemplateType.blankPants:
        return ['Torso', 'Right Leg', 'Left Leg'];
      case ClothingTemplateType.blankShirt:
        return ['Torso', 'Right Arm', 'Left Arm'];
      case ClothingTemplateType.blankTShirt:
        return ['Front Decal'];
    }
  }

  /// Official UV canvas dimensions for this template type.
  Size get uvCanvasSize {
    switch (this) {
      case ClothingTemplateType.blankPants:
        return const Size(585, 559);
      case ClothingTemplateType.blankShirt:
        return const Size(585, 559);
      case ClothingTemplateType.blankTShirt:
        return const Size(128, 128);
    }
  }

  /// The Roblox class name this template produces.
  String get robloxClassName {
    switch (this) {
      case ClothingTemplateType.blankPants:
        return 'Pants';
      case ClothingTemplateType.blankShirt:
        return 'Shirt';
      case ClothingTemplateType.blankTShirt:
        return 'ShirtGraphic';
    }
  }

  IconData get icon {
    switch (this) {
      case ClothingTemplateType.blankPants:
        return Icons.straighten;
      case ClothingTemplateType.blankShirt:
        return Icons.checkroom;
      case ClothingTemplateType.blankTShirt:
        return Icons.crop_portrait;
    }
  }

  /// Map from Supabase template_type string to enum.
  static ClothingTemplateType? fromString(String type) {
    switch (type) {
      case 'classic_pants': return ClothingTemplateType.blankPants;
      case 'classic_shirt': return ClothingTemplateType.blankShirt;
      case 'classic_tshirt': return ClothingTemplateType.blankTShirt;
      default: return null;
    }
  }
}

/// Typed contract for passing parameters to the `/editor` route.
///
/// Usage:
/// ```dart
/// context.push('/editor', extra: EditorRouteParams(
///   mode: EditorMode.classicClothingBlankStart,
///   clothingTemplate: ClothingTemplateType.blankShirt,
/// ));
/// ```
class EditorRouteParams {
  final EditorMode mode;
  final ClothingTemplateType? clothingTemplate;

  /// Pre-designed texture paths for set templates (local assets).
  final String? shirtAssetPath;
  final String? pantsAssetPath;

  /// Existing saved project UUID (library reopen).
  final String? projectId;

  const EditorRouteParams({
    required this.mode,
    this.clothingTemplate,
    this.shirtAssetPath,
    this.pantsAssetPath,
    this.projectId,
  });
}
