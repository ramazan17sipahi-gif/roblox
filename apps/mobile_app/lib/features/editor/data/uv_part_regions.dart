import 'package:flutter/material.dart';

import 'editor_route_params.dart';

/// One labeled panel on the classic clothing UV guide.
class UvGuidePanel {
  final Rect rect;
  final String label;
  final Color color;

  const UvGuidePanel({
    required this.rect,
    required this.label,
    required this.color,
  });
}

/// Official Roblox classic clothing UV face islands (585×559 atlas).
///
/// Coordinates match `threejs_viewer.html` PART_FACES / TORSO / LIMB tables
/// (scanned from the classic Shirt.png template). Empty gaps between faces
/// are intentionally not paintable — that is what makes the 2D editor look
/// like a clothing template instead of a solid rectangle.
class UvPartRegions {
  UvPartRegions._();

  static const atlasSize = Size(585, 559);

  static const _shirtTorsoColor = Color(0xFFFF6A1A);
  static const _shirtLimbColor = Color(0xFFE85D04);
  static const _pantsTorsoColor = Color(0xFF00897B);
  static const _pantsLimbColor = Color(0xFF26A69A);
  static const _tshirtColor = Color(0xFFFF793A);

  // ── Atlas face geometry (pixel space @ 585×559) ──────────────────────

  static const _torsoY = 73.0;
  static const _torsoH = 130.0;

  static const _torsoFaces = <Rect>[
    Rect.fromLTWH(164, _torsoY, 66, _torsoH), // R
    Rect.fromLTWH(231, _torsoY, 130, _torsoH), // Front
    Rect.fromLTWH(362, _torsoY, 64, _torsoH), // L
    Rect.fromLTWH(427, _torsoY, 130, _torsoH), // Back
    Rect.fromLTWH(231, 7, 130, 65), // Up
    Rect.fromLTWH(231, 204, 130, 64), // Down
  ];

  static const _limbY = 349.0;
  static const _limbH = 114.0;

  static const _rightLimbFaces = <Rect>[
    Rect.fromLTWH(18, _limbY, 66, _limbH), // L
    Rect.fromLTWH(85, _limbY, 66, _limbH), // B
    Rect.fromLTWH(151, _limbY, 66, _limbH), // R
    Rect.fromLTWH(217, _limbY, 66, _limbH), // F
    Rect.fromLTWH(217, 288, 66, 62), // Up
  ];

  static const _leftLimbFaces = <Rect>[
    Rect.fromLTWH(308, _limbY, 66, _limbH), // F
    Rect.fromLTWH(374, _limbY, 66, _limbH), // R
    Rect.fromLTWH(440, _limbY, 66, _limbH), // B
    Rect.fromLTWH(506, _limbY, 66, _limbH), // L
    Rect.fromLTWH(308, 288, 66, 62), // Up
  ];

  /// Face islands for [partName] in [canvasSize] space.
  static List<Rect> facesFor(String partName, Size canvasSize) {
    if (partName == 'Front Decal') {
      return [Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height)];
    }

    final base = switch (partName) {
      'Torso' => _torsoFaces,
      'Right Arm' || 'Right Leg' => _rightLimbFaces,
      'Left Arm' || 'Left Leg' => _leftLimbFaces,
      _ => const <Rect>[],
    };
    if (base.isEmpty) return const [];

    final scaleX = canvasSize.width / atlasSize.width;
    final isStacked = canvasSize.height > atlasSize.height + 1;
    final scaleY = isStacked ? 1.0 : canvasSize.height / atlasSize.height;
    final yOff = isStacked &&
            (partName == 'Right Leg' || partName == 'Left Leg')
        ? atlasSize.height + 10
        : 0.0;

    return [
      for (final r in base)
        Rect.fromLTWH(
          r.left * scaleX,
          r.top * scaleY + yOff,
          r.width * scaleX,
          r.height * scaleY,
        ),
    ];
  }

  /// Axis-aligned bounds of all faces (used for part chips / coarse hit).
  static Rect boundsFor(String partName, Size canvasSize) {
    final faces = facesFor(partName, canvasSize);
    if (faces.isEmpty) {
      return Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    }
    var left = faces.first.left;
    var top = faces.first.top;
    var right = faces.first.right;
    var bottom = faces.first.bottom;
    for (final f in faces.skip(1)) {
      left = left < f.left ? left : f.left;
      top = top < f.top ? top : f.top;
      right = right > f.right ? right : f.right;
      bottom = bottom > f.bottom ? bottom : f.bottom;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Path covering every paintable face of [partName].
  static Path facePathFor(String partName, Size canvasSize) {
    final path = Path();
    for (final r in facesFor(partName, canvasSize)) {
      path.addRect(r);
    }
    return path;
  }

  /// Path of every face across [partNames] (full clothing template silhouette).
  static Path templatePath(Size canvasSize, List<String> partNames) {
    final path = Path();
    for (final name in partNames) {
      path.addPath(facePathFor(name, canvasSize), Offset.zero);
    }
    return path;
  }

  /// Which face rect contains [uvPos] for [partName], if any.
  static Rect? faceAt(Offset uvPos, String partName, Size canvasSize) {
    for (final r in facesFor(partName, canvasSize)) {
      if (r.contains(uvPos)) return r;
    }
    return null;
  }

  /// Which editable part owns [uvPos] (face hit preferred; smallest area wins).
  static String? partAt(Offset uvPos, Size canvasSize, List<String> partNames) {
    String? best;
    var bestArea = double.infinity;
    for (final name in partNames) {
      final face = faceAt(uvPos, name, canvasSize);
      if (face != null) {
        final area = face.width * face.height;
        if (area < bestArea) {
          bestArea = area;
          best = name;
        }
        continue;
      }
      // Fallback: coarse AABB (gaps between faces still select the part).
      final bounds = boundsFor(name, canvasSize);
      if (!bounds.contains(uvPos)) continue;
      final area = bounds.width * bounds.height;
      if (area < bestArea) {
        bestArea = area;
        best = name;
      }
    }
    return best;
  }

  /// Short labels for drawing the template guide.
  static List<(Rect, String)> labeledFaces(
    String partName,
    Size canvasSize, {
    ClothingTemplateType? template,
  }) {
    final faces = facesFor(partName, canvasSize);
    if (faces.isEmpty) return const [];
    if (partName == 'Front Decal') {
      return [(faces.first, 'Ön Decal')];
    }
    final isPants = template == ClothingTemplateType.blankPants ||
        partName.contains('Leg');
    if (partName == 'Torso' && faces.length >= 6) {
      if (isPants) {
        return [
          (faces[0], 'R'),
          (faces[1], 'Bel Ön'),
          (faces[2], 'L'),
          (faces[3], 'Bel Arka'),
          (faces[4], 'Üst'),
          (faces[5], 'Alt'),
        ];
      }
      return [
        (faces[0], 'R'),
        (faces[1], 'Ön'),
        (faces[2], 'L'),
        (faces[3], 'Arka'),
        (faces[4], 'Üst'),
        (faces[5], 'Alt'),
      ];
    }
    if (faces.length >= 5) {
      // Make it obvious these are arms vs legs — not interchangeable.
      final isLeg = partName.contains('Leg') || isPants;
      final side = partName.startsWith('Right') ? 'Sağ' : 'Sol';
      final kind = isLeg ? 'Bacak' : 'Kol';
      final tag = '$side $kind';
      return [
        (faces[0], tag),
        (faces[1], ''),
        (faces[2], ''),
        (faces[3], ''),
        (faces[4], 'Üst'),
      ];
    }
    return [for (final f in faces) (f, '')];
  }

  /// Template-colored UV guide panels for the active clothing type.
  ///
  /// Shirt → torso + arms (orange). Pants → waist + legs (teal).
  /// T-Shirt → full 128×128 front decal (coral).
  static List<UvGuidePanel> guidePanelsFor(
    ClothingTemplateType template,
    Size canvasSize, {
    List<String>? parts,
  }) {
    final partNames = parts ?? template.activeParts;
    final panels = <UvGuidePanel>[];

    for (final name in partNames) {
      final color = _guideColorFor(template, name);
      for (final (rect, label) in labeledFaces(
        name,
        canvasSize,
        template: template,
      )) {
        panels.add(UvGuidePanel(rect: rect, label: label, color: color));
      }
    }
    return panels;
  }

  static Color _guideColorFor(ClothingTemplateType template, String partName) {
    // Part name wins so set mode (shirt+pants) can show orange arms + teal legs.
    if (partName.contains('Leg')) return _pantsLimbColor;
    if (partName.contains('Arm')) return _shirtLimbColor;
    switch (template) {
      case ClothingTemplateType.blankPants:
        return _pantsTorsoColor;
      case ClothingTemplateType.blankShirt:
      case ClothingTemplateType.blankTShirt:
        return _shirtTorsoColor;
    }
  }

  /// Short badge text shown on the 2D canvas for the open template.
  static String guideBadgeFor(ClothingTemplateType template) {
    switch (template) {
      case ClothingTemplateType.blankTShirt:
      case ClothingTemplateType.blankShirt:
        return 'Shirt UV · 585×559';
      case ClothingTemplateType.blankPants:
        return 'Pants UV · 585×559';
    }
  }
}
