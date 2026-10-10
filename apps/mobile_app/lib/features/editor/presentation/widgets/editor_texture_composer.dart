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

  /// Front-torso region the JS engine reads for `tshirt` mode (UpperTorso.front
  /// in threejs_viewer.html PART_FACES). The 128×128 decal canvas is fitted into
  /// this rect so it lands on the character's chest instead of being clipped
  /// away at the atlas origin.
  static const _tshirtFrontRect = Rect.fromLTWH(231, 73, 130, 98);

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

    final isTshirt = jsMode == 'tshirt';

    int totalRendered = 0;
    int totalSkipped = 0;
    for (final partName in partNames) {
      final drawing = partDrawings[partName];
      if (drawing == null) continue;
      if (drawing.strokes.isEmpty && drawing.elements.isEmpty) continue;

      final src = drawing.sourceCanvasSize ?? const Size(atlasW, atlasH);

      final partRecorder = ui.PictureRecorder();
      final partCanvas = Canvas(partRecorder);

      late final double sx;
      late final double sy;
      late final Rect partBounds;
      Offset tshirtOrigin = Offset.zero;
      if (isTshirt) {
        final fitX = _tshirtFrontRect.width / src.width;
        final fitY = _tshirtFrontRect.height / src.height;
        final scale = fitX < fitY ? fitX : fitY;
        sx = scale;
        sy = scale;
        partBounds = _tshirtFrontRect;
        final drawW = src.width * scale;
        final drawH = src.height * scale;
        tshirtOrigin = Offset(
          _tshirtFrontRect.left + (_tshirtFrontRect.width - drawW) / 2,
          _tshirtFrontRect.top + (_tshirtFrontRect.height - drawH) / 2,
        );
      } else {
        sx = atlasW / src.width;
        sy = atlasH / src.height;
        partBounds = UvPartRegions.boundsFor(
          partName,
          const Size(atlasW, atlasH),
        );
      }

      void beginPartSpace({required bool faceIslandsOnly}) {
        partCanvas.save();
        if (isTshirt) {
          partCanvas.clipRect(partBounds);
          partCanvas.translate(tshirtOrigin.dx, tshirtOrigin.dy);
        } else if (faceIslandsOnly) {
          partCanvas.clipPath(
            UvPartRegions.facePathFor(partName, const Size(atlasW, atlasH)),
          );
        } else {
          // Stickers: AABB clip so narrow arm columns don't erase overhang.
          partCanvas.clipRect(partBounds);
        }
      }

      beginPartSpace(faceIslandsOnly: true);
      for (final stroke in drawing.strokes) {
        EditorAtlasReplay.replayStroke(
          partCanvas,
          stroke,
          atlasSize: const Size(atlasW, atlasH),
          sx: sx,
          sy: sy,
        );
      }
      partCanvas.restore();

      beginPartSpace(faceIslandsOnly: false);
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
      // Set canvas is stacked (shirt 559 + gap + pants 559). Strokes live in
      // that space; each output atlas is still 585×559 — shift pants down.
      final stackedSize = Size(atlasW, atlasH + setGap + atlasH);
      // Keep 1:1 mapping in set mode; pants are recentered via translate.
      final useSetCoords = isSetMode && src.height > atlasH + 1;
      final strokeSx = useSetCoords ? 1.0 : atlasW / src.width;
      final strokeSy = useSetCoords ? 1.0 : atlasH / src.height;
      final isPantsPart =
          isSetMode && (partName == 'Right Leg' || partName == 'Left Leg');
      final stackToAtlasShift = isPantsPart ? -(atlasH + setGap) : 0.0;

      final sortedStrokes = List.of(drawing.strokes)
        ..sort((a, b) => (layerOrder[a.layerId ?? 'base'] ?? 0)
            .compareTo(layerOrder[b.layerId ?? 'base'] ?? 0));
      final sortedElements = List.of(drawing.elements)
        ..sort((a, b) => (layerOrder[a.layerId ?? 'base'] ?? 0)
            .compareTo(layerOrder[b.layerId ?? 'base'] ?? 0));

      final partRecorder = ui.PictureRecorder();
      final partCanvas = Canvas(partRecorder);
      final clipSpace =
          useSetCoords ? stackedSize : const Size(atlasW, atlasH);
      final partBounds = UvPartRegions.boundsFor(partName, clipSpace);

      void withPartSpace({required bool faceIslandsOnly, required void Function() paint}) {
        partCanvas.save();
        if (stackToAtlasShift != 0) {
          partCanvas.translate(0, stackToAtlasShift);
        }
        if (faceIslandsOnly) {
          partCanvas.clipPath(UvPartRegions.facePathFor(partName, clipSpace));
        } else {
          partCanvas.clipRect(partBounds);
        }
        paint();
        partCanvas.restore();
      }

      withPartSpace(faceIslandsOnly: true, paint: () {
        for (final stroke in sortedStrokes) {
          final strokeLayerId = stroke.layerId ?? 'base';
          final strokeLayer =
              layerState.layers.where((l) => l.id == strokeLayerId).firstOrNull;
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
            atlasSize: useSetCoords ? stackedSize : const Size(atlasW, atlasH),
            sx: strokeSx,
            sy: strokeSy,
          );
          if (strokeOpacity < 1.0) partCanvas.restore();
        }
      });

      withPartSpace(faceIslandsOnly: false, paint: () {
        for (final element in sortedElements) {
          final elemLayerId = element.layerId ?? 'base';
          final elemLayer =
              layerState.layers.where((l) => l.id == elemLayerId).firstOrNull;
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
            sx: strokeSx,
            sy: strokeSy,
            yOffset: 0,
          );
          if (elemOpacity < 1.0) partCanvas.restore();
        }
      });

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
