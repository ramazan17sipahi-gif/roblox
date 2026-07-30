import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../presentation/widgets/drawing_canvas.dart';

/// Serializes / deserializes classic clothing editor canvas state.
class EditorProjectSerializer {
  static Future<Map<String, dynamic>> serializeAsync({
    required Map<String, PartDrawing> partDrawings,
    required String templateType,
    required int activePartIndex,
    required List<String> partNames,
    required List<Map<String, dynamic>> layers,
    required String activeLayerId,
    String? shirtAssetPath,
    String? pantsAssetPath,
  }) async {
    final parts = <String, dynamic>{};
    for (final entry in partDrawings.entries) {
      parts[entry.key] = await _serializePartAsync(entry.value);
    }

    return {
      'version': 3,
      'template_type': templateType,
      'active_part_index': activePartIndex,
      'active_layer_id': activeLayerId,
      'part_names': partNames,
      'layers': layers,
      'shirt_asset_path': shirtAssetPath,
      'pants_asset_path': pantsAssetPath,
      'parts': parts,
    };
  }

  static Future<Map<String, dynamic>> _serializePartAsync(PartDrawing part) async {
    final elements = <Map<String, dynamic>>[];
    for (final e in part.elements) {
      elements.add(await _serializeElementAsync(e));
    }
    return {
      'strokes': part.strokes.map(_serializeStroke).toList(),
      'elements': elements,
    };
  }

  static Map<String, dynamic> _serializeStroke(DrawStroke s) {
    return {
      'points': s.points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': s.color.toARGB32(),
      'width': s.width,
      'opacity': s.opacity,
      'is_eraser': s.isEraser,
      'blend_mode': s.blendMode.index,
      'shape_type': s.shapeType.index,
      'shape_filled': s.shapeFilled,
      'shape_start': s.shapeStart != null
          ? {'x': s.shapeStart!.dx, 'y': s.shapeStart!.dy}
          : null,
      'shape_end': s.shapeEnd != null
          ? {'x': s.shapeEnd!.dx, 'y': s.shapeEnd!.dy}
          : null,
      'gradient_type': s.gradientType.index,
      'gradient_end_color': s.gradientEndColor?.toARGB32(),
      'layer_id': s.layerId,
    };
  }

  static Future<Map<String, dynamic>> _serializeElementAsync(CanvasElement e) async {
    final map = {
      'id': e.id,
      'text': e.text,
      'text_style': e.textStyle != null
          ? {
              'color': e.textStyle!.color?.toARGB32(),
              'font_size': e.textStyle!.fontSize,
              'font_weight': e.textStyle!.fontWeight?.value,
            }
          : null,
      'position': {'x': e.position.dx, 'y': e.position.dy},
      'scale': e.scale,
      'rotation': e.rotation,
      'opacity': e.opacity,
      'flip_h': e.flipH,
      'flip_v': e.flipV,
      'target_part': e.targetPart,
      'target_face': e.targetFace,
      'layer_id': e.layerId,
      'image_asset_path': null as String?,
      'image_png_base64': null as String?,
    };

    if (e.image != null) {
      final byteData = await e.image!.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        map['image_png_base64'] = base64Encode(byteData.buffer.asUint8List());
      }
    }

    return map;
  }

  /// Applies serialized JSON onto existing [partDrawings] (clears first).
  /// Returns active layer id from project (or null for default).
  static Future<String?> deserializeAsync(
    Map<String, dynamic> json,
    Map<String, PartDrawing> partDrawings,
  ) async {
    final parts = json['parts'] as Map<String, dynamic>? ?? {};
    for (final entry in parts.entries) {
      final part = partDrawings[entry.key];
      if (part == null) continue;
      part.strokes.clear();
      part.elements.clear();
      final data = entry.value as Map<String, dynamic>;
      for (final s in (data['strokes'] as List? ?? [])) {
        part.strokes.add(_deserializeStroke(s as Map<String, dynamic>));
      }
      for (final e in (data['elements'] as List? ?? [])) {
        part.elements.add(await _deserializeElementAsync(e as Map<String, dynamic>));
      }
    }
    return json['active_layer_id'] as String?;
  }

  static List<dynamic>? layersFromProject(Map<String, dynamic> json) =>
      json['layers'] as List<dynamic>?;

  static DrawStroke _deserializeStroke(Map<String, dynamic> m) {
    Offset? readPoint(Map<String, dynamic>? p) =>
        p == null ? null : Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble());

    return DrawStroke(
      points: (m['points'] as List? ?? [])
          .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
          .toList(),
      color: Color(m['color'] as int),
      width: (m['width'] as num).toDouble(),
      opacity: (m['opacity'] as num?)?.toDouble() ?? 1.0,
      isEraser: m['is_eraser'] as bool? ?? false,
      blendMode: BlendMode.values[m['blend_mode'] as int? ?? 0],
      shapeType: ShapeType.values[m['shape_type'] as int? ?? 0],
      shapeFilled: m['shape_filled'] as bool? ?? true,
      shapeStart: readPoint(m['shape_start'] as Map<String, dynamic>?),
      shapeEnd: readPoint(m['shape_end'] as Map<String, dynamic>?),
      gradientType: GradientFillType.values[m['gradient_type'] as int? ?? 0],
      gradientEndColor: m['gradient_end_color'] != null
          ? Color(m['gradient_end_color'] as int)
          : null,
      layerId: m['layer_id'] as String?,
    );
  }

  static Future<CanvasElement> _deserializeElementAsync(Map<String, dynamic> m) async {
    TextStyle? style;
    final ts = m['text_style'] as Map<String, dynamic>?;
    if (ts != null) {
      FontWeight? weight;
      final weightValue = ts['font_weight'] as int?;
      if (weightValue != null) {
        weight = FontWeight.values.firstWhere(
          (w) => w.value == weightValue,
          orElse: () => FontWeight.w700,
        );
      }
      style = TextStyle(
        color: ts['color'] != null ? Color(ts['color'] as int) : null,
        fontSize: (ts['font_size'] as num?)?.toDouble(),
        fontWeight: weight ?? FontWeight.w700,
      );
    }

    ui.Image? image;
    final assetPath = m['image_asset_path'] as String?;
    if (assetPath != null && assetPath.isNotEmpty) {
      image = await _loadImageFromAsset(assetPath);
    } else {
      final b64 = m['image_png_base64'] as String?;
      if (b64 != null && b64.isNotEmpty) {
        image = await _decodePngBase64(b64);
      }
    }

    return CanvasElement(
      id: m['id'] as String,
      image: image,
      text: m['text'] as String?,
      textStyle: style,
      position: Offset(
        (m['position']['x'] as num).toDouble(),
        (m['position']['y'] as num).toDouble(),
      ),
      scale: (m['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (m['rotation'] as num?)?.toDouble() ?? 0.0,
      opacity: (m['opacity'] as num?)?.toDouble() ?? 1.0,
      flipH: m['flip_h'] as bool? ?? false,
      flipV: m['flip_v'] as bool? ?? false,
      targetPart: m['target_part'] as String?,
      targetFace: m['target_face'] as String?,
      layerId: m['layer_id'] as String?,
    );
  }

  static Future<ui.Image?> _decodePngBase64(String b64) async {
    try {
      final raw = b64.contains(',') ? b64.split(',').last : b64;
      final bytes = base64Decode(raw);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image?> _loadImageFromAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Uint8List? decodeBase64Png(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      final raw = base64Str.contains(',')
          ? base64Str.split(',').last
          : base64Str;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }
}
