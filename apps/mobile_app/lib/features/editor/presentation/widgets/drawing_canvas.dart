import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../data/editor_route_params.dart';
import '../../data/uv_part_regions.dart';
import '../editor_state.dart';
import '../editor_tool_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  ENUMS
// ═══════════════════════════════════════════════════════════════════════════

/// Shape types available in the editor.
enum ShapeType { none, rectangle, circle, triangle, line, star }

/// Gradient types available for fills and strokes.
enum GradientFillType { none, linear, radial }

// ═══════════════════════════════════════════════════════════════════════════
//  DRAW STROKE — single brush stroke / shape / gradient fill
// ═══════════════════════════════════════════════════════════════════════════

class DrawStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final double opacity;
  final bool isEraser;
  final BlendMode blendMode;

  // Shape support
  final ShapeType shapeType;
  final bool shapeFilled;
  final Offset? shapeStart;
  final Offset? shapeEnd;

  // Gradient support
  final GradientFillType gradientType;
  final Color? gradientEndColor;

  // Layer association (null = default layer)
  final String? layerId;

  DrawStroke({
    required this.points,
    required this.color,
    required this.width,
    this.opacity = 1.0,
    this.isEraser = false,
    this.blendMode = BlendMode.srcOver,
    this.shapeType = ShapeType.none,
    this.shapeFilled = true,
    this.shapeStart,
    this.shapeEnd,
    this.gradientType = GradientFillType.none,
    this.gradientEndColor,
    this.layerId,
  });

  /// Create a copy with updated fields.
  DrawStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? width,
    double? opacity,
    bool? isEraser,
    BlendMode? blendMode,
    ShapeType? shapeType,
    bool? shapeFilled,
    Offset? shapeStart,
    Offset? shapeEnd,
    GradientFillType? gradientType,
    Color? gradientEndColor,
    String? layerId,
  }) {
    return DrawStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
      isEraser: isEraser ?? this.isEraser,
      blendMode: blendMode ?? this.blendMode,
      shapeType: shapeType ?? this.shapeType,
      shapeFilled: shapeFilled ?? this.shapeFilled,
      shapeStart: shapeStart ?? this.shapeStart,
      shapeEnd: shapeEnd ?? this.shapeEnd,
      gradientType: gradientType ?? this.gradientType,
      gradientEndColor: gradientEndColor ?? this.gradientEndColor,
      layerId: layerId ?? this.layerId,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CANVAS ELEMENT — positioned/transformed Image, Text, or Sticker
// ═══════════════════════════════════════════════════════════════════════════

class CanvasElement {
  String id;
  ui.Image? image;
  String? text;
  TextStyle? textStyle;
  /// Demo font label (e.g. "Bold Impact") for re-opening the text editor.
  String? textFont;
  Offset position;
  double scale;
  double rotation; // radians
  double opacity;
  bool flipH;
  bool flipV;

  // Sticker UV metadata — enables face-aware 3D mapping
  String? targetPart;  // e.g. 'UpperTorso', 'LowerTorso'
  String? targetFace;  // 'front', 'back', 'left', 'right', 'up', 'down'

  // Layer association (null = default layer)
  String? layerId;

  // Cached text dimensions (computed lazily)
  double? _cachedTextW;
  double? _cachedTextH;

  CanvasElement({
    required this.id,
    this.image,
    this.text,
    this.textStyle,
    this.textFont,
    this.position = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.flipH = false,
    this.flipV = false,
    this.targetPart,
    this.targetFace,
    this.layerId,
  });

  /// Intrinsic content width (before scale).
  double get contentWidth {
    if (image != null) return image!.width.toDouble();
    if (text != null && textStyle != null) {
      _measureText();
      return _cachedTextW!;
    }
    return 100.0;
  }

  /// Intrinsic content height (before scale).
  double get contentHeight {
    if (image != null) return image!.height.toDouble();
    if (text != null && textStyle != null) {
      _measureText();
      return _cachedTextH!;
    }
    return 40.0;
  }

  void _measureText() {
    if (_cachedTextW != null) return;
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    _cachedTextW = tp.width;
    _cachedTextH = tp.height;
  }

  /// Call after changing [text] or [textStyle] so hit-test / layout stay correct.
  void invalidateTextCache() {
    _cachedTextW = null;
    _cachedTextH = null;
  }

  CanvasElement clone() {
    return CanvasElement(
      id: '${id}_copy_${DateTime.now().millisecondsSinceEpoch}',
      image: image,
      text: text,
      textStyle: textStyle,
      textFont: textFont,
      position: position + const Offset(20, 20),
      scale: scale,
      rotation: rotation,
      opacity: opacity,
      flipH: flipH,
      flipV: flipV,
      targetPart: targetPart,
      targetFace: targetFace,
      layerId: layerId,
    );
  }

  Rect get bounds {
    final w = contentWidth * scale;
    final h = contentHeight * scale;
    return Rect.fromLTWH(position.dx, position.dy, w, h);
  }

  /// Transform-aware hit test.
  ///
  /// Maps [point] into the element's local image space (accounting for
  /// position, rotation, flip) and checks whether it falls within
  /// [0..imgW, 0..imgH] + [padding] px tolerance.
  ///
  /// This replaces the old AABB test which failed for rotated stickers.
  bool hitTest(Offset point, {double padding = 12.0}) {
    final sW = contentWidth * scale;
    final sH = contentHeight * scale;

    // Centre of the element in canvas space (post-position, post-scale)
    final cx = position.dx + sW / 2;
    final cy = position.dy + sH / 2;

    // Translate point to element-centre-relative
    var dx = point.dx - cx;
    var dy = point.dy - cy;

    // Un-rotate (inverse rotation)
    if (rotation != 0) {
      final cos = math.cos(-rotation);
      final sin = math.sin(-rotation);
      final rdx = dx * cos - dy * sin;
      final rdy = dx * sin + dy * cos;
      dx = rdx;
      dy = rdy;
    }

    // Un-flip — flip applied AFTER scale in painter, so undo before checking
    if (flipH) dx = -dx;
    if (flipV) dy = -dy;

    // Point is now in element-local space centred at (sW/2, sH/2)
    // Check against half-extents with padding
    final hit = dx.abs() <= sW / 2 + padding && dy.abs() <= sH / 2 + padding;
    return hit;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PART DRAWING — full drawing data for a single UV part
// ═══════════════════════════════════════════════════════════════════════════

class PartDrawing {
  final String partName;
  final List<DrawStroke> strokes;
  final List<CanvasElement> elements;
  ui.Image? importedImage;
  Offset imageOffset;
  double imageScale;
  double imageRotation;

  /// Canonical coordinate space for this part's drawing data.
  /// All strokes/elements are stored in this widget-pixel space.
  /// Updated via [migrateToSize] — never overwritten blindly.
  Size? sourceCanvasSize;

  PartDrawing({
    required this.partName,
    List<DrawStroke>? strokes,
    List<CanvasElement>? elements,
    this.importedImage,
    this.imageOffset = Offset.zero,
    this.imageScale = 1.0,
    this.imageRotation = 0.0,
    this.sourceCanvasSize,
  })  : strokes = strokes ?? [],
        elements = elements ?? [];

  /// Updates [sourceCanvasSize] safely.
  ///
  /// - If [newSize] matches current size (within 0.5px tolerance) → no-op.
  /// - If part has no content → update directly.
  /// - Otherwise → rescale all coordinate data, then update size.
  ///
  /// Returns whether a migration was performed.
  bool migrateToSize(Size newSize) {
    final old = sourceCanvasSize;
    if (old == null) {
      sourceCanvasSize = newSize;
      return false;
    }
    // Tolerance check — avoid spurious migrations from sub-pixel jitter
    if ((newSize.width - old.width).abs() < 0.5 &&
        (newSize.height - old.height).abs() < 0.5) {
      return false;
    }
    final rx = newSize.width / old.width;
    final ry = newSize.height / old.height;
    final rAvg = (rx + ry) / 2;
    final isEmpty = strokes.isEmpty && elements.isEmpty;
    if (!isEmpty) {
      // Rescale strokes
      for (int i = 0; i < strokes.length; i++) {
        final s = strokes[i];
        strokes[i] = s.copyWith(
          points: s.points.map((p) => Offset(p.dx * rx, p.dy * ry)).toList(),
          width: s.width * rAvg,
          shapeStart: s.shapeStart != null
              ? Offset(s.shapeStart!.dx * rx, s.shapeStart!.dy * ry)
              : null,
          shapeEnd: s.shapeEnd != null
              ? Offset(s.shapeEnd!.dx * rx, s.shapeEnd!.dy * ry)
              : null,
        );
      }
      // Rescale elements
      for (final el in elements) {
        el.position = Offset(el.position.dx * rx, el.position.dy * ry);
        el.scale = el.scale * rAvg;
      }
      debugPrint(
        '[coord-migrate] part=$partName '
        'old=${old.width.toStringAsFixed(1)}x${old.height.toStringAsFixed(1)} '
        'new=${newSize.width.toStringAsFixed(1)}x${newSize.height.toStringAsFixed(1)} '
        'rx=${rx.toStringAsFixed(3)} ry=${ry.toStringAsFixed(3)} '
        'migrated=${strokes.length + elements.length}',
      );
    }
    sourceCanvasSize = newSize;
    return !isEmpty;
  }
}

/// Maps a tap on the fitted UV viewport into canonical UV coordinates.
Offset localToUv(Offset local, Size containerSize, Size uvSize) {
  final scaleX = containerSize.width / uvSize.width;
  final scaleY = containerSize.height / uvSize.height;
  final scale = scaleX < scaleY ? scaleX : scaleY;
  final renderedW = uvSize.width * scale;
  final renderedH = uvSize.height * scale;
  final offsetX = (containerSize.width - renderedW) / 2;
  final offsetY = (containerSize.height - renderedH) / 2;
  return Offset(
    (local.dx - offsetX) / scale,
    (local.dy - offsetY) / scale,
  );
}

/// Hit-tests canvas elements top-to-bottom in UV space.
CanvasElement? findElementAt(PartDrawing partDrawing, Offset uvPosition) {
  for (int i = partDrawing.elements.length - 1; i >= 0; i--) {
    if (partDrawing.elements[i].hitTest(uvPosition)) {
      return partDrawing.elements[i];
    }
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════════════════
//  DRAWING CANVAS WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class DrawingCanvas extends StatefulWidget {
  final Size uvSize;
  final PartDrawing partDrawing;
  final Color activeColor;
  final double brushWidth;
  final double brushOpacity;
  final int activeTool; // 0=Draw, 1=Fill, 2=Erase, 3=Gradient, 4=Shape

  /// Optional [TransformationController] from the parent [InteractiveViewer].
  /// When provided, all pointer positions are unmapped through the inverse
  /// view transform before being stored — ensuring coordinates are always in
  /// canonical drawing space regardless of zoom/pan state.
  final TransformationController? transformationController;

  /// Fires the instant the user first touches the canvas (pan or tap).
  final VoidCallback? onInteractionStart;

  /// Fires when a drawing stroke (brush/shape/fill/gradient) is finalized.
  final VoidCallback? onStrokeCommitted;

  /// Fires once when an element drag ends or after a discrete element mutation.
  final VoidCallback? onElementChanged;

  /// Fires every frame during element drag.
  final VoidCallback? onElementDragging;

  // Shape mode props
  final ShapeType activeShape;
  final bool shapeFilled;

  // Gradient mode props
  final GradientFillType activeGradientType;
  final Color? gradientEndColor;

  // Blend mode
  final BlendMode activeBlendMode;

  // Element selection
  final String? selectedElementId;
  final ValueChanged<String?>? onElementSelected;

  // Layer-aware rendering
  final List<EditorLayer>? layers;
  final String? activeLayerId;

  /// All editable parts for this template (e.g. Torso / Arms / Legs).
  /// When set with [allPartDrawings], taps auto-target the part under the finger.
  final List<String>? editableParts;

  /// Full part → drawing map so fills/strokes can land on the tapped part
  /// even when it is not the currently selected tab.
  final Map<String, PartDrawing>? allPartDrawings;

  /// Called when a paint gesture activates a different body part.
  final ValueChanged<String>? onPartActivated;

  /// Draw labeled clothing face panels (Front / Back / Arms…).
  final bool showFaceGuide;

  /// Which classic clothing UV layout to draw (Shirt / Pants / T-Shirt).
  final ClothingTemplateType? templateType;

  /// When false, only paints — pointer events pass through to [InteractiveViewer].
  final bool inputEnabled;

  const DrawingCanvas({
    super.key,
    required this.uvSize,
    required this.partDrawing,
    required this.activeColor,
    required this.brushWidth,
    required this.brushOpacity,
    required this.activeTool,
    this.transformationController,
    this.onInteractionStart,
    this.onStrokeCommitted,
    this.onElementChanged,
    this.onElementDragging,
    this.activeShape = ShapeType.rectangle,
    this.shapeFilled = true,
    this.activeGradientType = GradientFillType.linear,
    this.gradientEndColor,
    this.activeBlendMode = BlendMode.srcOver,
    this.selectedElementId,
    this.onElementSelected,
    this.layers,
    this.activeLayerId,
    this.editableParts,
    this.allPartDrawings,
    this.onPartActivated,
    this.showFaceGuide = true,
    this.templateType,
    this.inputEnabled = true,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  DrawStroke? _currentStroke;
  Offset? _shapeStart;

  // Element interaction
  bool _isDraggingElement = false;
  Offset _dragStartOffset = Offset.zero;
  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  // Listener-based gesture tracking
  bool _pointerDown = false;
  bool _hasMoved = false;
  Offset _pointerDownPos = Offset.zero;
  int _activePointerCount = 0;

  /// Part drawing that receives the in-progress brush/shape stroke.
  PartDrawing? _gestureTargetDrawing;

  double get _realBrushWidth => 2 + widget.brushWidth * 28;

  List<String> get _editableParts =>
      widget.editableParts ?? [widget.partDrawing.partName];

  /// Resolve which part owns [uvPos], preferring the smallest matching region.
  String? _partAt(Offset uvPos) =>
      UvPartRegions.partAt(uvPos, widget.uvSize, _editableParts);

  /// Activate [partName] if needed and return its [PartDrawing].
  PartDrawing? _activatePart(String partName) {
    final map = widget.allPartDrawings;
    final drawing = map?[partName] ??
        (partName == widget.partDrawing.partName ? widget.partDrawing : null);
    if (drawing == null) return null;
    if (partName != widget.partDrawing.partName) {
      widget.onPartActivated?.call(partName);
    }
    return drawing;
  }

  bool _isLayerLocked(String? layerId) {
    final layers = widget.layers;
    if (layers == null || layers.isEmpty) return false;
    final id = layerId ?? EditorState.baseLayerId;
    final layer = layers.where((l) => l.id == id).firstOrNull;
    return layer?.isLocked ?? false;
  }

  bool get _isActiveLayerLocked => _isLayerLocked(widget.activeLayerId);

  String? get _commitLayerId => widget.activeLayerId ?? EditorState.baseLayerId;

  /// Body parts that occupy a sub-region of the UV atlas. Painting is confined
  /// to this region so a stroke on one part never bleeds onto another part's
  /// faces once composed into the 3D texture (WYSIWYG with the atlas composer).
  static const _clippedParts = {
    'Torso',
    'Right Arm',
    'Left Arm',
    'Right Leg',
    'Left Leg',
  };

  /// The active part's paintable region, or null when the whole canvas is
  /// editable (e.g. T-Shirt front decal).
  Rect? get _activePartClip {
    final part = widget.partDrawing.partName;
    if (!_clippedParts.contains(part)) return null;
    return UvPartRegions.boundsFor(part, widget.uvSize);
  }

  Path? get _activePartFacePath {
    final part = widget.partDrawing.partName;
    if (!_clippedParts.contains(part)) return null;
    return UvPartRegions.facePathFor(part, widget.uvSize);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final uvSize = widget.uvSize; // 585×559

        // Store sourceCanvasSize as UV size (not screen size!)
        // This ensures atlas compose uses sx=1.0, sy=1.0
        if (widget.partDrawing.sourceCanvasSize == null) {
          widget.partDrawing.sourceCanvasSize = uvSize;
        }

        // FittedBox scales the UV-sized child to fit screen.
        // Listener is INSIDE FittedBox so localPosition is already in UV space.
        // Render every part's strokes (each clipped to its UV island) so the 2D
        // view matches the 3D atlas — not only the active tab.
        final partLayers = <_PartPaintLayer>[];
        final map = widget.allPartDrawings;
        if (map != null) {
          for (final name in _editableParts) {
            final d = map[name];
            if (d == null) continue;
            partLayers.add(_PartPaintLayer(
              partName: name,
              strokes: d.strokes,
              elements: d.elements,
              clipPath: _clippedParts.contains(name)
                  ? UvPartRegions.facePathFor(name, uvSize)
                  : null,
            ));
          }
        } else {
          partLayers.add(_PartPaintLayer(
            partName: widget.partDrawing.partName,
            strokes: widget.partDrawing.strokes,
            elements: widget.partDrawing.elements,
            clipPath: _activePartFacePath,
          ));
        }

        final gesturePath = _gestureTargetDrawing != null
            ? UvPartRegions.facePathFor(
                _gestureTargetDrawing!.partName, uvSize)
            : _activePartFacePath;

        final paint = CustomPaint(
          painter: _CanvasPainter(
            partLayers: partLayers,
            currentStroke: _currentStroke,
            currentStrokeClipPath: gesturePath,
            importedImage: widget.partDrawing.importedImage,
            imageOffset: widget.partDrawing.imageOffset,
            imageScale: widget.partDrawing.imageScale,
            selectedElementId: widget.selectedElementId,
            layers: widget.layers,
            activeLayerId: widget.activeLayerId,
            activeClipPath: _activePartFacePath,
            templateType: widget.templateType,
            guidePanels: widget.showFaceGuide
                ? (widget.templateType != null
                    ? UvPartRegions.guidePanelsFor(
                        widget.templateType!,
                        uvSize,
                        parts: _editableParts,
                      )
                    : [
                        for (final name in _editableParts)
                          for (final (rect, label)
                              in UvPartRegions.labeledFaces(name, uvSize))
                            UvGuidePanel(
                              rect: rect,
                              label: label,
                              color: const Color(0xFFFF6A1A),
                            ),
                      ])
                : const [],
          ),
          size: uvSize,
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox(
              width: uvSize.width,
              height: uvSize.height,
              child: widget.inputEnabled
                  ? Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      child: paint,
                    )
                  : paint,
            ),
          ),
        );
      },
    );
  }

  /// Maps a raw pointer position into UV drawing space.
  ///
  /// Because Listener is inside FittedBox, Flutter's hit-test system
  /// already transforms localPosition into the child's coordinate space
  /// (UV space). No manual conversion needed — identity mapping.
  Offset _toDrawingSpace(Offset raw) => raw;

  // ─── POINTER HANDLERS (raw — bypasses gesture arena entirely) ──────

  void _cancelActiveInteraction() {
    _pointerDown = false;
    _hasMoved = false;
    _isDraggingElement = false;
    _currentStroke = null;
    _shapeStart = null;
    _gestureTargetDrawing = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.inputEnabled) return;
    _activePointerCount++;
    // Two-finger gesture → let InteractiveViewer handle pinch/pan.
    if (_activePointerCount > 1) {
      _cancelActiveInteraction();
      return;
    }
    _pointerDown = true;
    _hasMoved = false;
    _pointerDownPos = event.localPosition;
    _gestureTargetDrawing = null;
    widget.onInteractionStart?.call();
    final pos = _toDrawingSpace(event.localPosition);

    // ── Priority 1: Drag already-selected element ──
    if (widget.selectedElementId != null) {
      final element = widget.partDrawing.elements
          .where((e) => e.id == widget.selectedElementId)
          .firstOrNull;
      if (element != null && element.hitTest(pos)) {
        if (_isLayerLocked(element.layerId)) return;
        _isDraggingElement = true;
        _dragStartOffset = pos - element.position;
        widget.onElementDragging?.call();
        return;
      }
    }

    // ── Priority 2: Auto-select + drag if pointer starts on an unselected element ──
    // Hit-test across all parts so stickers on inactive limbs stay selectable.
    final hitDrawing = _drawingContainingElementAt(pos);
    final hitElement = hitDrawing == null
        ? null
        : findElementAt(hitDrawing, pos);
    if (hitElement != null && hitDrawing != null) {
      if (_isLayerLocked(hitElement.layerId)) return;
      if (hitDrawing.partName != widget.partDrawing.partName) {
        widget.onPartActivated?.call(hitDrawing.partName);
      }
      widget.onElementSelected?.call(hitElement.id);
      _isDraggingElement = true;
      _dragStartOffset = pos - hitElement.position;
      widget.onElementDragging?.call();
      setState(() {});
      return;
    }

    // ── Hand/navigate: select & drag elements only — never draw ──
    if (widget.activeTool == EditorDrawToolIndex.navigate) return;

    // ── Sticker picker mode: no canvas drawing ──
    if (widget.activeTool == EditorDrawToolIndex.sticker) return;

    // ── Locked active layer: no new strokes ──
    if (_isActiveLayerLocked) return;

    // ── Fill / Gradient: discrete tap on pointer-up only ──
    if (widget.activeTool == EditorDrawToolIndex.fill ||
        widget.activeTool == EditorDrawToolIndex.gradient) {
      return;
    }

    // ── Resolve part under the finger (arm/leg tap switches target) ──
    final hitPart = _partAt(pos);
    if (hitPart == null) return;
    // Brush/shape only start on a real clothing face — not empty gaps.
    if (_clippedParts.contains(hitPart) &&
        UvPartRegions.faceAt(pos, hitPart, widget.uvSize) == null) {
      return;
    }
    final target = _activatePart(hitPart);
    if (target == null) return;
    _gestureTargetDrawing = target;

    // ── Shape tool ──
    if (widget.activeTool == EditorDrawToolIndex.shape) {
      _shapeStart = pos;
      _currentStroke = DrawStroke(
        points: [pos],
        color: widget.activeColor,
        width: _realBrushWidth,
        opacity: widget.brushOpacity,
        blendMode: widget.activeBlendMode,
        shapeType: widget.activeShape,
        shapeFilled: widget.shapeFilled,
        shapeStart: pos,
        shapeEnd: pos,
        layerId: _commitLayerId,
      );
      setState(() {});
      return;
    }

    // ── Brush / Eraser only ──
    if (!EditorDrawToolIndex.isDragDrawingTool(widget.activeTool)) return;

    final isEraser = widget.activeTool == EditorDrawToolIndex.eraser;
    _currentStroke = DrawStroke(
      points: [pos],
      color: isEraser ? Colors.white : widget.activeColor,
      width: _realBrushWidth,
      opacity: isEraser ? 1.0 : widget.brushOpacity,
      isEraser: isEraser,
      blendMode: isEraser ? BlendMode.clear : widget.activeBlendMode,
      layerId: _commitLayerId,
    );
    setState(() {});
  }

  PartDrawing? _drawingContainingElementAt(Offset pos) {
    final map = widget.allPartDrawings;
    if (map == null) {
      return findElementAt(widget.partDrawing, pos) != null
          ? widget.partDrawing
          : null;
    }
    // Top-most: walk parts in reverse so later limbs win ties.
    for (final name in _editableParts.reversed) {
      final drawing = map[name];
      if (drawing == null) continue;
      if (findElementAt(drawing, pos) != null) return drawing;
    }
    return null;
  }

  /// Move the selected sticker/image onto the UV part under its center and
  /// snap into a paintable face so Right Arm / Left Arm drops don't vanish.
  void _rehomeSelectedElement() {
    final id = widget.selectedElementId;
    final map = widget.allPartDrawings;
    if (id == null || map == null) return;

    PartDrawing? owner;
    CanvasElement? el;
    for (final d in map.values) {
      final found = d.elements.where((e) => e.id == id).firstOrNull;
      if (found != null) {
        owner = d;
        el = found;
        break;
      }
    }
    if (owner == null || el == null) return;

    final halfW = el.contentWidth * el.scale / 2;
    final halfH = el.contentHeight * el.scale / 2;
    var center = Offset(el.position.dx + halfW, el.position.dy + halfH);

    var hitPart = UvPartRegions.partAt(center, widget.uvSize, _editableParts);
    if (hitPart == null) {
      // Nearest part by face-center distance (gaps between islands).
      var bestDist = double.infinity;
      for (final name in _editableParts) {
        for (final face in UvPartRegions.facesFor(name, widget.uvSize)) {
          final d = (face.center - center).distanceSquared;
          if (d < bestDist) {
            bestDist = d;
            hitPart = name;
          }
        }
      }
    }
    if (hitPart == null) return;

    final faces = UvPartRegions.facesFor(hitPart, widget.uvSize);
    if (faces.isNotEmpty) {
      Rect? containing;
      for (final f in faces) {
        if (f.contains(center)) {
          containing = f;
          break;
        }
      }
      containing ??= faces.reduce((a, b) =>
          (a.center - center).distanceSquared <= (b.center - center).distanceSquared
              ? a
              : b);
      final clamped = Offset(
        center.dx.clamp(containing.left + 2, containing.right - 2),
        center.dy.clamp(containing.top + 2, containing.bottom - 2),
      );
      if (clamped != center) {
        el.position = Offset(clamped.dx - halfW, clamped.dy - halfH);
        center = clamped;
      }
    }

    el.targetPart = hitPart;
    if (hitPart != owner.partName) {
      owner.elements.remove(el);
      map[hitPart]?.elements.add(el);
      widget.onPartActivated?.call(hitPart);
      debugPrint('[sticker-rehome] id=$id from=${owner.partName} to=$hitPart '
          'center=(${center.dx.toStringAsFixed(1)},${center.dy.toStringAsFixed(1)})');
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointerDown || _activePointerCount > 1) return;
    // Mark as moved if distance exceeds tap tolerance
    if (!_hasMoved && (event.localPosition - _pointerDownPos).distance > 8.0) {
      _hasMoved = true;
    }
    if (!_hasMoved) return;

    final pos = _toDrawingSpace(event.localPosition);

    if (_isDraggingElement && widget.selectedElementId != null) {
      // Search active + all parts for the selected element id.
      CanvasElement? element = widget.partDrawing.elements
          .where((e) => e.id == widget.selectedElementId)
          .firstOrNull;
      if (element == null && widget.allPartDrawings != null) {
        for (final d in widget.allPartDrawings!.values) {
          element = d.elements.where((e) => e.id == widget.selectedElementId).firstOrNull;
          if (element != null) break;
        }
      }
      if (element != null) {
        element.position = pos - _dragStartOffset;
        widget.onElementDragging?.call();
        setState(() {});
      }
      return;
    }

    if (_currentStroke == null) return;

    // Keep the stroke inside a clothing face island (not the empty gaps).
    final target = _gestureTargetDrawing ?? widget.partDrawing;
    final faces = _clippedParts.contains(target.partName)
        ? UvPartRegions.facesFor(target.partName, widget.uvSize)
        : const <Rect>[];
    Offset clamped = pos;
    if (faces.isNotEmpty) {
      final inside = faces.any((f) => f.contains(pos));
      if (!inside) {
        // Snap to nearest face center so strokes don't bleed into gaps.
        Rect nearest = faces.first;
        var best = double.infinity;
        for (final f in faces) {
          final d = (f.center - pos).distanceSquared;
          if (d < best) {
            best = d;
            nearest = f;
          }
        }
        clamped = Offset(
          pos.dx.clamp(nearest.left, nearest.right),
          pos.dy.clamp(nearest.top, nearest.bottom),
        );
      }
    }

    if (widget.activeTool == EditorDrawToolIndex.shape && _shapeStart != null) {
      _currentStroke = _currentStroke!.copyWith(
        shapeEnd: clamped,
        points: [_shapeStart!, clamped],
      );
      setState(() {});
      return;
    }

    _currentStroke!.points.add(clamped);
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointerCount = (_activePointerCount - 1).clamp(0, 10);
    if (!widget.inputEnabled || !_pointerDown) return;
    _pointerDown = false;

    // ── TAP (no significant move) ──
    if (!_hasMoved) {
      final pos = _toDrawingSpace(event.localPosition);

      // Hit-test elements across all parts first
      final hitDrawing = _drawingContainingElementAt(pos);
      final hitElement =
          hitDrawing == null ? null : findElementAt(hitDrawing, pos);
      if (hitElement != null && hitDrawing != null) {
        if (hitDrawing.partName != widget.partDrawing.partName) {
          widget.onPartActivated?.call(hitDrawing.partName);
        }
        widget.onElementSelected?.call(hitElement.id);
        setState(() {});
        _isDraggingElement = false;
        _gestureTargetDrawing = null;
        return;
      }

      // Tool-specific tap: fill / gradient — use the part under the tap.
      if (!_isActiveLayerLocked) {
        if (widget.activeTool == EditorDrawToolIndex.fill) {
          _onFillTap(pos);
          _isDraggingElement = false;
          _gestureTargetDrawing = null;
          return;
        } else if (widget.activeTool == EditorDrawToolIndex.gradient) {
          _onGradientFill(pos);
          _isDraggingElement = false;
          _gestureTargetDrawing = null;
          return;
        }
      }

      // Tapped empty area → deselect
      if (widget.selectedElementId != null) {
        widget.onElementSelected?.call(null);
        setState(() {});
      }
      _isDraggingElement = false;
      _gestureTargetDrawing = null;
      return;
    }

    // ── DRAG END ──
    if (_isDraggingElement) {
      // Stickers/images stay owned by the part they were spawned on. When the
      // user drags onto another limb (e.g. Right Arm), re-home them so the
      // face clip + 3D atlas don't erase the content.
      _rehomeSelectedElement();
      _isDraggingElement = false;
      _gestureTargetDrawing = null;
      widget.onElementChanged?.call();
      return;
    }

    if (_currentStroke == null) {
      _gestureTargetDrawing = null;
      return;
    }
    final target = _gestureTargetDrawing ?? widget.partDrawing;
    target.strokes.add(_currentStroke!);
    _currentStroke = null;
    _shapeStart = null;
    _gestureTargetDrawing = null;
    widget.onStrokeCommitted?.call();
    setState(() {});
  }

  // ─── FILL ───────────────────────────────────────────────────────────

  void _onFillTap(Offset uvPos) {
    final hitPart = _partAt(uvPos);
    if (hitPart == null) {
      debugPrint('[fill] miss uv=${uvPos.dx.toStringAsFixed(1)},${uvPos.dy.toStringAsFixed(1)}');
      return;
    }
    final drawing = _activatePart(hitPart);
    if (drawing == null) return;
    drawing.sourceCanvasSize ??= widget.uvSize;

    // Fill only the clothing face under the finger (template panel), not the
    // empty gaps around it. If the tap is in a gap, fill every face of the part.
    final hitFace = UvPartRegions.faceAt(uvPos, hitPart, widget.uvSize);
    final targets = hitFace != null
        ? <Rect>[hitFace]
        : UvPartRegions.facesFor(hitPart, widget.uvSize);
    if (targets.isEmpty) return;

    for (final rect in targets) {
      drawing.strokes.add(DrawStroke(
        points: [rect.topLeft, rect.bottomRight],
        color: widget.activeColor,
        width: 1,
        opacity: widget.brushOpacity,
        blendMode: widget.activeBlendMode,
        shapeType: ShapeType.rectangle,
        shapeFilled: true,
        shapeStart: rect.topLeft,
        shapeEnd: rect.bottomRight,
        layerId: _commitLayerId,
      ));
    }
    debugPrint(
      '[fill] part=$hitPart faces=${targets.length} '
      'color=${widget.activeColor.toARGB32().toRadixString(16)}',
    );
    widget.onStrokeCommitted?.call();
    setState(() {});
  }

  // ─── GRADIENT FILL ──────────────────────────────────────────────────

  void _onGradientFill(Offset uvPos) {
    final hitPart = _partAt(uvPos);
    if (hitPart == null) return;
    final drawing = _activatePart(hitPart);
    if (drawing == null) return;
    drawing.sourceCanvasSize ??= widget.uvSize;

    final hitFace = UvPartRegions.faceAt(uvPos, hitPart, widget.uvSize);
    final targets = hitFace != null
        ? <Rect>[hitFace]
        : UvPartRegions.facesFor(hitPart, widget.uvSize);
    if (targets.isEmpty) return;

    for (final rect in targets) {
      drawing.strokes.add(DrawStroke(
        points: [rect.topLeft, rect.bottomRight],
        color: widget.activeColor,
        width: 1,
        opacity: widget.brushOpacity,
        blendMode: widget.activeBlendMode,
        gradientType: widget.activeGradientType,
        gradientEndColor: widget.gradientEndColor ?? Colors.white,
        shapeType: ShapeType.rectangle,
        shapeFilled: true,
        shapeStart: rect.topLeft,
        shapeEnd: rect.bottomRight,
        layerId: _commitLayerId,
      ));
    }
    widget.onStrokeCommitted?.call();
    setState(() {});
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CANVAS PAINTER — renders strokes, shapes, gradients, elements
// ═══════════════════════════════════════════════════════════════════════════

class _PartPaintLayer {
  final String partName;
  final List<DrawStroke> strokes;
  final List<CanvasElement> elements;
  final Path? clipPath;

  const _PartPaintLayer({
    required this.partName,
    required this.strokes,
    required this.elements,
    this.clipPath,
  });
}

class _CanvasPainter extends CustomPainter {
  final List<_PartPaintLayer> partLayers;
  final DrawStroke? currentStroke;
  final Path? currentStrokeClipPath;
  final ui.Image? importedImage;
  final Offset imageOffset;
  final double imageScale;
  final String? selectedElementId;
  final List<EditorLayer>? layers;
  final String? activeLayerId;

  /// Active part face path — dimmed outside so editable panels are clear.
  final Path? activeClipPath;

  /// Clothing template guide (face rect + short label + per-type color).
  final List<UvGuidePanel> guidePanels;

  /// Drives T-Shirt silhouette guide vs classic shirt/pants face panels.
  final ClothingTemplateType? templateType;

  _CanvasPainter({
    required this.partLayers,
    this.currentStroke,
    this.currentStrokeClipPath,
    this.importedImage,
    this.imageOffset = Offset.zero,
    this.imageScale = 1.0,
    this.selectedElementId,
    this.layers,
    this.activeLayerId,
    this.activeClipPath,
    this.guidePanels = const [],
    this.templateType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Layer 0: Imported image
    if (importedImage != null) {
      final src = Rect.fromLTWH(0, 0, importedImage!.width.toDouble(), importedImage!.height.toDouble());
      final dst = Rect.fromLTWH(
        imageOffset.dx, imageOffset.dy,
        importedImage!.width * imageScale,
        importedImage!.height * imageScale,
      );
      canvas.drawImageRect(importedImage!, src, dst, Paint());
    }

    // Classic Roblox UV face islands (Shirt / Pants / T-Shirt → same shirt UV).
    if (guidePanels.isNotEmpty) {
      final fontSize = size.width < 200 ? 7.0 : 9.0;
      for (final panel in guidePanels) {
        final fill = Paint()..color = panel.color.withValues(alpha: 0.10);
        final stroke = Paint()
          ..color = panel.color.withValues(alpha: 0.70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        canvas.drawRRect(
          RRect.fromRectAndRadius(panel.rect, const Radius.circular(3)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(panel.rect, const Radius.circular(3)),
          stroke,
        );
        if (panel.label.isEmpty) continue;
        final tp = TextPainter(
          text: TextSpan(
            text: panel.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: panel.color.withValues(alpha: 0.85),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: panel.rect.width - 4);
        tp.paint(
          canvas,
          Offset(panel.rect.left + 3, panel.rect.top + 2),
        );
      }
    }

    void paintPartContent(
      Canvas canvas,
      List<DrawStroke> strokes,
      List<CanvasElement> elements,
    ) {
      if (layers != null && layers!.isNotEmpty) {
        for (final layer in layers!) {
          if (!layer.isVisible) continue;
          if (layer.opacity < 1.0) {
            canvas.saveLayer(
              Rect.fromLTWH(0, 0, size.width, size.height),
              Paint()..color = Color.fromRGBO(255, 255, 255, layer.opacity),
            );
          }
          for (final stroke in strokes) {
            final sid = stroke.layerId ?? 'base';
            if (sid == layer.id) _drawStroke(canvas, stroke, size);
          }
          for (final element in elements) {
            final eid = element.layerId ?? 'base';
            if (eid == layer.id) _drawElement(canvas, element);
          }
          if (layer.opacity < 1.0) canvas.restore();
        }
      } else {
        for (final stroke in strokes) {
          _drawStroke(canvas, stroke, size);
        }
        for (final element in elements) {
          _drawElement(canvas, element);
        }
      }
    }

    // Strokes: clip to clothing face islands.
    // Elements (stickers/images): draw unclipped so dragging onto another limb
    // stays visible until re-home assigns the correct part.
    for (final part in partLayers) {
      final partClip = part.clipPath;
      if (partClip != null) {
        canvas.save();
        canvas.clipPath(partClip);
      }
      paintPartContent(canvas, part.strokes, const []);
      if (partClip != null) canvas.restore();
    }
    for (final part in partLayers) {
      paintPartContent(canvas, const [], part.elements);
    }

    // Current in-progress stroke (always on top), clipped to face islands.
    if (currentStroke != null) {
      final strokeClip = currentStrokeClipPath;
      if (strokeClip != null) {
        canvas.save();
        canvas.clipPath(strokeClip);
      }
      _drawStroke(canvas, currentStroke!, size);
      if (strokeClip != null) canvas.restore();
    }

    final clip = activeClipPath;
    if (clip != null) {
      final outside = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addPath(clip, Offset.zero)
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(
        outside,
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.22),
      );
      canvas.drawPath(
        clip,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7),
      );
    }
  }

  void _drawStroke(Canvas canvas, DrawStroke stroke, Size size) {
    // ── Gradient fill ──
    if (stroke.gradientType != GradientFillType.none) {
      _drawGradientFill(canvas, stroke, size);
      return;
    }

    // ── Shape ──
    if (stroke.shapeType != ShapeType.none &&
        stroke.shapeStart != null &&
        stroke.shapeEnd != null) {
      _drawShape(canvas, stroke);
      return;
    }

    // ── Free draw / erase ──
    if (stroke.points.length < 2) {
      if (stroke.points.isNotEmpty) {
        final paint = Paint()
          ..color = stroke.color.withValues(alpha: stroke.opacity)
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.fill
          ..blendMode = stroke.isEraser ? BlendMode.clear : stroke.blendMode;
        canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
      }
      return;
    }

    final paint = Paint()
      ..color = stroke.color.withValues(alpha: stroke.opacity)
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = stroke.isEraser ? BlendMode.clear : stroke.blendMode;

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length; i++) {
      if (i < stroke.points.length - 1) {
        final mid = Offset(
          (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
          (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(stroke.points[i].dx, stroke.points[i].dy, mid.dx, mid.dy);
      } else {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  // ─── GRADIENT FILL ──────────────────────────────────────────────────

  void _drawGradientFill(Canvas canvas, DrawStroke stroke, Size size) {
    final rect = (stroke.shapeStart != null && stroke.shapeEnd != null)
        ? Rect.fromPoints(stroke.shapeStart!, stroke.shapeEnd!)
        : Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..blendMode = stroke.blendMode;

    final endColor = stroke.gradientEndColor ?? Colors.white;

    if (stroke.gradientType == GradientFillType.linear) {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          stroke.color.withValues(alpha: stroke.opacity),
          endColor.withValues(alpha: stroke.opacity),
        ],
      ).createShader(rect);
    } else if (stroke.gradientType == GradientFillType.radial) {
      paint.shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          stroke.color.withValues(alpha: stroke.opacity),
          endColor.withValues(alpha: stroke.opacity),
        ],
      ).createShader(rect);
    }

    canvas.drawRect(rect, paint);
  }

  // ─── SHAPES ─────────────────────────────────────────────────────────

  void _drawShape(Canvas canvas, DrawStroke stroke) {
    final start = stroke.shapeStart!;
    final end = stroke.shapeEnd!;
    final paint = Paint()
      ..color = stroke.color.withValues(alpha: stroke.opacity)
      ..strokeWidth = stroke.width
      ..blendMode = stroke.blendMode
      ..style = stroke.shapeFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = Rect.fromPoints(start, end);

    switch (stroke.shapeType) {
      case ShapeType.rectangle:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          paint,
        );
        break;
      case ShapeType.circle:
        canvas.drawOval(rect, paint);
        break;
      case ShapeType.triangle:
        final path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.line:
        canvas.drawLine(start, end, paint..style = PaintingStyle.stroke);
        break;
      case ShapeType.star:
        _drawStar(canvas, rect.center, math.min(rect.width, rect.height) / 2, paint);
        break;
      default:
        break;
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const points = 5;
    final innerRadius = radius * 0.45;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : innerRadius;
      final angle = (i * math.pi / points) - math.pi / 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // ─── ELEMENTS (Stickers, Text, Images) ──────────────────────────────

  void _drawElement(Canvas canvas, CanvasElement element) {
    canvas.save();
    canvas.translate(element.position.dx, element.position.dy);

    if (element.rotation != 0) {
      final center = Offset(
        element.contentWidth * element.scale / 2,
        element.contentHeight * element.scale / 2,
      );
      canvas.translate(center.dx, center.dy);
      canvas.rotate(element.rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    canvas.scale(
      element.flipH ? -element.scale : element.scale,
      element.flipV ? -element.scale : element.scale,
    );

    if (element.flipH) {
      canvas.translate(-element.contentWidth, 0);
    }
    if (element.flipV) {
      canvas.translate(0, -element.contentHeight);
    }

    final paint = Paint()..color = Colors.white.withValues(alpha: element.opacity);

    if (element.image != null) {
      canvas.drawImage(element.image!, Offset.zero, paint);
    }

    if (element.text != null && element.textStyle != null) {
      final tp = TextPainter(
        text: TextSpan(text: element.text, style: element.textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset.zero);
    }

    canvas.restore();

    // Selection border — rotation-aware (V10: enhanced handles)
    if (selectedElementId == element.id) {
      canvas.save();
      canvas.translate(element.position.dx, element.position.dy);

      final sW = element.contentWidth * element.scale;
      final sH = element.contentHeight * element.scale;

      // Rotate around element center (same as _drawElement paint)
      if (element.rotation != 0) {
        canvas.translate(sW / 2, sH / 2);
        canvas.rotate(element.rotation);
        canvas.translate(-sW / 2, -sH / 2);
      }

      final selRect = Rect.fromLTWH(-4, -4, sW + 8, sH + 8);

      // Dashed selection border
      final selPaint = Paint()
        ..color = const Color(0xFF2196F3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(selRect, selPaint);

      // Corner handles (white fill + blue border)
      const hs = 5.0;
      final handleFill = Paint()..color = const Color(0xFFFFFFFF);
      final handleStroke = Paint()
        ..color = const Color(0xFF2196F3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final corner in [
        selRect.topLeft,
        selRect.topRight,
        selRect.bottomLeft,
        selRect.bottomRight,
      ]) {
        final handleRect = Rect.fromCenter(center: corner, width: hs * 2, height: hs * 2);
        canvas.drawRect(handleRect, handleFill);
        canvas.drawRect(handleRect, handleStroke);
      }

      // Midpoint handles (smaller blue dots on edges)
      final midPaint = Paint()..color = const Color(0xFF2196F3);
      const midR = 3.0;
      canvas.drawCircle(Offset(selRect.center.dx, selRect.top), midR, midPaint);
      canvas.drawCircle(Offset(selRect.center.dx, selRect.bottom), midR, midPaint);
      canvas.drawCircle(Offset(selRect.left, selRect.center.dy), midR, midPaint);
      canvas.drawCircle(Offset(selRect.right, selRect.center.dy), midR, midPaint);

      // Rotation indicator — knob above the element
      final rotLineStart = Offset(selRect.center.dx, selRect.top);
      final rotLineEnd = Offset(selRect.center.dx, selRect.top - 20);
      canvas.drawLine(rotLineStart, rotLineEnd, selPaint);
      canvas.drawCircle(rotLineEnd, 5, handleFill);
      canvas.drawCircle(rotLineEnd, 5, handleStroke);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter old) => true;
}

