import 'package:flutter/material.dart';

/// Bounding boxes for Roblox classic clothing UV parts (585×559 atlas).
///
/// Layout matches the official shirt/pants template: torso faces in the upper
/// band, left/right limb faces in the lower band.
class UvPartRegions {
  UvPartRegions._();

  static const atlasSize = Size(585, 559);

  /// Returns the UV-space bounds for [partName], scaled to [canvasSize].
  ///
  /// In stacked set mode (height > 559), leg parts are offset onto the pants
  /// template below the shirt.
  static Rect boundsFor(String partName, Size canvasSize) {
    final base = _normalizedBounds(partName);
    final scaleX = canvasSize.width / atlasSize.width;
    // Non-stacked: map 0..559 → full height. Stacked: map within shirt/pants band.
    final isStacked = canvasSize.height > atlasSize.height + 1;
    final scaleY = isStacked
        ? 1.0
        : canvasSize.height / atlasSize.height;

    var rect = Rect.fromLTWH(
      base.left * scaleX,
      base.top * scaleY,
      base.width * scaleX,
      base.height * scaleY,
    );

    if (isStacked && (partName == 'Right Leg' || partName == 'Left Leg')) {
      // Pants template starts after shirt (559) + gap (10).
      rect = rect.translate(0, atlasSize.height + 10);
    }

    return rect;
  }

  static Rect _normalizedBounds(String partName) {
    switch (partName) {
      case 'Torso':
        // Upper template band (all torso faces).
        return const Rect.fromLTWH(0, 0, 585, 280);
      case 'Right Arm':
      case 'Right Leg':
        return const Rect.fromLTWH(0, 280, 292, 279);
      case 'Left Arm':
      case 'Left Leg':
        return const Rect.fromLTWH(293, 280, 292, 279);
      case 'Front Decal':
        return const Rect.fromLTWH(0, 0, 128, 128);
      default:
        return const Rect.fromLTWH(0, 0, 585, 559);
    }
  }
}
