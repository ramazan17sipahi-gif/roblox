import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/uv_part_regions.dart';
import '../editor_state.dart';
import 'drawing_canvas.dart';
import 'editor_atlas_replay.dart';

/// Composes Roblox classic clothing UV atlases from part drawings.
class EditorTextureComposer {
  EditorTextureComposer._();

  static const atlasW = 585.0;
  static const atlasH = 559.0;

  static Future<String?> composeFullAtlas({
    required Map<String, PartDrawing> partDrawings,
    required List<String> partNames,
    required String jsMode,
  }) async {
    final recorder = ui.PictureRecorder();
    final atlasCanvas = Canvas(recorder);

    atlasCanvas.drawRect(
      const Rect.fromLTWH(0, 0, atlasW, atlasH),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final firstDrawing = partDrawings[partNames.first];
    final baseImage = firstDrawing?.importedImage;
    if (baseImage != null) {
      atlasCanvas.drawImageRect(
        baseImage,
        Rect.fromLTWH(0, 0, baseImage.width.toDouble(), baseImage.height.toDouble()),
        const Rect.fromLTWH(0, 0, atlasW, atlasH),
        Paint(),
      );
      debugPrint('[atlas-layer] base_draw_once=true size=${baseImage.width}x${baseImage.height}');
    }

    int totalRendered = 0;
    int totalSkipped = 0;
    for (final partName in partNames) {
      final drawing = partDrawings[partName];
      if (drawing == null) continue;
      if (drawing.strokes.isEmpty && drawing.elements.isEmpty) continue;

      final src = drawing.sourceCanvasSize ?? const Size(atlasW, atlasH);
      final sx = atlasW / src.width;
      final sy = atlasH / src.height;

      final partRecorder = ui.PictureRecorder();
      final partCanvas = Canvas(partRecorder);
      final partClip = UvPartRegions.boundsFor(
        partName,
        const Size(atlasW, atlasH),
      );
      partCanvas.save();
      partCanvas.clipRect(partClip);

      for (final stroke in drawing.strokes) {
        EditorAtlasReplay.replayStroke(
          partCanvas,
          stroke,
          atlasSize: const Size(atlasW, atlasH),
          sx: sx,
          sy: sy,
        );
      }

      for (final element in drawing.elements) {
        if (element.targetPart != null &&
            element.targetPart!.isNotEmpty &&
            element.targetPart != 'unknown' &&
            element.targetPart != partName) {
          totalSkipped++;
          continue;
        }
        EditorAtlasReplay.replayElement(partCanvas, element, sx: sx, sy: sy);
        totalRendered++;
      }

      partCanvas.restore();
      final partPicture = partRecorder.endRecording();
      final partImage = await partPicture.toImage(atlasW.toInt(), atlasH.toInt());
      atlasCanvas.drawImage(partImage, Offset.zero, Paint());
    }

    final picture = recorder.endRecording();
    final atlasImage = await picture.toImage(atlasW.toInt(), atlasH.toInt());
    final byteData = await atlasImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      debugPrint('[atlas-sync] mode=$jsMode parts=${partNames.join("+")} result=error_null_bytes');
      return null;
    }

    debugPrint('[atlas-verify] mode=$jsMode totalParts=${partNames.length} '
        'renderedElements=$totalRendered skippedByFilter=$totalSkipped '
        'atlasSize=${atlasW.toInt()}x${atlasH.toInt()} '
        'bytesGenerated=${byteData.lengthInBytes}');
    return base64Encode(byteData.buffer.asUint8List());
  }

  static Future<String?> composeLayerAtlas({
    required Map<String, PartDrawing> partDrawings,
    required List<String> layerParts,
    required ui.Image? baseImage,
    required EditorState layerState,
    required String jsMode,
    double setGap = 10,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, atlasW, atlasH),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    if (baseImage != null) {
      canvas.drawImageRect(
        baseImage,
        Rect.fromLTWH(0, 0, baseImage.width.toDouble(), baseImage.height.toDouble()),
        const Rect.fromLTWH(0, 0, atlasW, atlasH),
        Paint(),
      );
    }

    final layerOrder = <String, int>{};
    for (int li = 0; li < layerState.layers.length; li++) {
      layerOrder[layerState.layers[li].id] = li;
    }

    for (final partName in layerParts) {
      final drawing = partDrawings[partName];
      if (drawing == null) continue;
      if (drawing.strokes.isEmpty && drawing.elements.isEmpty) continue;

      final src = drawing.sourceCanvasSize ?? const Size(atlasW, atlasH);
      final isSetMode = jsMode == 'set';
      final sx = atlasW / (isSetMode ? atlasW : src.width);
      final sy = atlasH / (isSetMode ? atlasH : src.height);
      final isPantsPart = isSetMode && ['Right Leg', 'Left Leg'].contains(partName);
      final yOffset = isPantsPart ? (559 + setGap) : 0.0;

      final sortedStrokes = List.of(drawing.strokes)
        ..sort((a, b) => (layerOrder[a.layerId ?? 'base'] ?? 0)
            .compareTo(layerOrder[b.layerId ?? 'base'] ?? 0));
      final sortedElements = List.of(drawing.elements)
        ..sort((a, b) => (layerOrder[a.layerId ?? 'base'] ?? 0)
            .compareTo(layerOrder[b.layerId ?? 'base'] ?? 0));

      final partRecorder = ui.PictureRecorder();
      final partCanvas = Canvas(partRecorder);
      // Part images are always 585×559; use non-stacked limb/torso bounds.
      final partClip = UvPartRegions.boundsFor(
        partName,
        const Size(atlasW, atlasH),
      );
      partCanvas.save();
      partCanvas.clipRect(partClip);

      for (final stroke in sortedStrokes) {
        final strokeLayerId = stroke.layerId ?? 'base';
        final strokeLayer = layerState.layers.where((l) => l.id == strokeLayerId).firstOrNull;
        if (strokeLayer != null && !strokeLayer.isVisible) continue;

        final strokeOpacity = strokeLayer?.opacity ?? 1.0;
        if (strokeOpacity < 1.0) {
          partCanvas.saveLayer(
            Rect.fromLTWH(0, 0, atlasW, atlasH),
            Paint()..color = Color.fromRGBO(255, 255, 255, strokeOpacity),
          );
        }
        EditorAtlasReplay.replayStroke(
          partCanvas,
          stroke,
          atlasSize: const Size(atlasW, atlasH),
          sx: sx,
          sy: sy,
        );
        if (strokeOpacity < 1.0) partCanvas.restore();
      }

      for (final element in sortedElements) {
        final elemLayerId = element.layerId ?? 'base';
        final elemLayer = layerState.layers.where((l) => l.id == elemLayerId).firstOrNull;
        if (elemLayer != null && !elemLayer.isVisible) continue;

        final elemOpacity = elemLayer?.opacity ?? 1.0;
        if (elemOpacity < 1.0) {
          partCanvas.saveLayer(
            Rect.fromLTWH(0, 0, atlasW, atlasH),
            Paint()..color = Color.fromRGBO(255, 255, 255, elemOpacity),
          );
        }
        EditorAtlasReplay.replayElement(
          partCanvas,
          element,
          sx: sx,
          sy: sy,
          yOffset: yOffset,
        );
        if (elemOpacity < 1.0) partCanvas.restore();
      }

      partCanvas.restore();
      final partPicture = partRecorder.endRecording();
      final partImage = await partPicture.toImage(atlasW.toInt(), atlasH.toInt());
      canvas.drawImage(partImage, Offset.zero, Paint());
    }

    final picture = recorder.endRecording();
    final atlasImage = await picture.toImage(atlasW.toInt(), atlasH.toInt());
    final byteData = await atlasImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return base64Encode(byteData.buffer.asUint8List());
  }
}
