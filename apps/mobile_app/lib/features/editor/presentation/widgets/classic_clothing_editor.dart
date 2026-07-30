import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:design_system/design_system.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'threejs_preview.dart';
import '../editor_state.dart';
import '../editor_tool_constants.dart';
import '../../data/editor_route_params.dart';
import '../../data/editor_project_serializer.dart';
import '../../data/project_id.dart';
import '../../data/project_repository.dart';
import '../../data/reference_image_upload_service.dart';
import 'drawing_canvas.dart';
import 'sticker_sheet.dart';
import 'element_controls.dart';
import 'editor_2d_tool_rail.dart';
import 'editor_draw_controls_panel.dart';
import 'editor_texture_composer.dart';
import 'layer_panel.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'publish_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dual-mode Classic Clothing Editor â€” starts in 3D, switches to 2D UV.
///
/// Architecture:
/// - Single ThreeJSPreview instance (key preserved across mode switches)
/// - 3D mode: full-screen mannequin + 5-tab toolbar
/// - 2D mode: UV canvas + mini 3D preview + 6-tab toolbar
/// - Element selected: toolbar switches to 6 context actions
/// - All mutable state is LOCAL (no EditorState mutation)
class ClassicClothingEditor extends StatefulWidget {
  final ClothingTemplateType template;

  /// Pre-designed texture asset paths (local assets).
  final String? shirtAssetPath;
  final String? pantsAssetPath;

  /// When set, loads an existing saved project from Supabase.
  final String? projectId;

  const ClassicClothingEditor({
    super.key,
    required this.template,
    this.shirtAssetPath,
    this.pantsAssetPath,
    this.projectId,
  });

  @override
  State<ClassicClothingEditor> createState() => _ClassicClothingEditorState();
}

class _ClassicClothingEditorState extends State<ClassicClothingEditor>
    with SingleTickerProviderStateMixin {
  final GlobalKey _canvasKey = GlobalKey();
  final GlobalKey<ThreeJSPreviewState> _threejsKey = GlobalKey<ThreeJSPreviewState>();
  Timer? _syncDebounce;

  /// Tracks zoom/pan state of the [InteractiveViewer] in 2D mode.
  final TransformationController _viewTransform = TransformationController();

  // â”€â”€ Latest-wins live sync queue â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //
  // Design: exactly one async worker runs at a time. If a new drag frame
  // arrives while the worker is busy, we overwrite _liveSyncLatestPending
  // (not a queue â€” only the newest position matters). When the worker
  // finishes it immediately picks up the pending frame if one exists.
  // No debounce Timer â€” the first frame fires instantly.
  //
  // Stale-seq protection: each request gets a monotone seq number.
  // If a newer request has already started by the time an older compose
  // finishes, the result is discarded instead of applied.
  int  _liveSyncSeq            = 0;  // increments on every request
  bool _liveSyncWorkerActive   = false;
  bool _liveSyncLatestPending  = false; // true = at least one frame waiting

  // â”€â”€ Content hash for skip-duplicate optimization â”€â”€
  int _lastShirtHash = 0;
  int _lastPantsHash = 0;
  int _lastFullHash  = 0;

  // â”€â”€ Model-ready pending sync â”€â”€
  bool _pendingSync = false;

  /// True while the user is actively dragging an element.
  /// Written directly (no setState) to avoid rebuilding InteractiveViewer mid-drag.
  bool _isDraggingElementGlobal = false;

  /// Last measured layout size of the UV canvas widget.
  /// Used by [_centerUvViewport] to compute the fit-to-center transform.
  Size _uvCanvasLayoutSize = Size.zero;

  // â”€â”€ Mode State (single source of truth) â”€â”€
  bool _isIn3DMode = true;
  int _activeToolIndex3D = 0;
  int _activeToolIndex2D = 0;
  bool _isPanelExpanded = false;
  bool _showFrontView = true;
  bool _showPlacementGrid = true;

  // â”€â”€ Part state â”€â”€
  int _activePartIndex = 0;
  late final Map<String, PartDrawing> _partDrawings;

  // â”€â”€ Layer state (shared with DrawingCanvas for layer-aware rendering) â”€â”€
  final EditorState _layerState = EditorState();

  // â”€â”€ Original base images for set mode (kept separate for per-layer sync) â”€â”€
  ui.Image? _shirtBaseImage;
  ui.Image? _pantsBaseImage;

  // â”€â”€ 2D Drawing Tool state â”€â”€
  /// Default: navigate/hand â€” pan & zoom without accidental strokes.
  int _activeDrawTool = EditorDrawToolIndex.navigate;
  Color _selectedColor = const Color(0xFFFF6A1A);
  Color _secondaryColor = const Color(0xFF2196F3);
  Color _tertiaryColor = const Color(0xFF4CAF50);
  int _activeColorSlot = 0;
  Color _gradientEndColor = const Color(0xFF2196F3);
  double _brushSize = 0.5;
  double _brushOpacity = 1.0;
  ShapeType _activeShape = ShapeType.rectangle;
  bool _shapeFilled = true;
  GradientFillType _activeGradientType = GradientFillType.linear;
  BlendMode _activeBlendMode = BlendMode.srcOver;

  // â”€â”€ 3D Color state (local only â€” P2 fix) â”€â”€
  Color _clothingBaseColor = const Color(0xFFA3A3A3);
  static const _presetColors = [
    Color(0xFF8B4513), Color(0xFF1565C0), Color(0xFF1A237E),
    Color(0xFF0D47A1), Color(0xFF827717), Color(0xFFBF360C),
    Color(0xFFA3A3A3), Color(0xFF000000),
  ];

  // â”€â”€ Project persistence â”€â”€
  late String _projectId;
  Timer? _autoSaveTimer;
  bool _isSaving = false;
  DateTime? _lastSavedAt;

  // â”€â”€ 3D Preview mini (2D mode) â”€â”€
  bool _previewExpanded = false;
  bool _previewMounted = true;

  // ── Undo / Redo ──
  final List<_UndoEntry> _undoStack = [];
  final List<_UndoEntry> _redoStack = [];

  // â”€â”€ Element selection â”€â”€
  String? _selectedElementId;
  CanvasElement? _clipboard;

  // â”€â”€ Color palette â”€â”€
  static const _colorPalette = [
    Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFFFF4444), Color(0xFF2196F3),
    Color(0xFF4CAF50), Color(0xFFFFEB3B), Color(0xFF9C27B0), Color(0xFFFF9800),
    Color(0xFF795548), Color(0xFF607D8B), Color(0xFFE91E63), Color(0xFF00BCD4),
    Color(0xFFFF6A1A), Color(0xFF00E5FF), Color(0xFF69F0AE), Color(0xFFB388FF),
  ];

  List<(IconData, String)> get _drawToolData {
    final l = AppLocalizations.of(context)!;
    return [
      (Icons.pan_tool_alt_outlined, l.editorDrawToolNavigate),
      (Icons.edit, l.editorDrawToolDraw),
      (Icons.format_color_fill, l.editorDrawToolFill),
      (Icons.auto_fix_off, l.editorDrawToolErase),
      (Icons.gradient, l.editorDrawToolGradient),
      (Icons.crop_square, l.editorDrawToolShape),
      (Icons.emoji_symbols, l.editorDrawToolSticker),
    ];
  }

  /// Maps rail index â†’ [EditorDrawToolIndex] value.
  static const _railToolValues = [
    EditorDrawToolIndex.navigate,
    EditorDrawToolIndex.brush,
    EditorDrawToolIndex.fill,
    EditorDrawToolIndex.eraser,
    EditorDrawToolIndex.gradient,
    EditorDrawToolIndex.shape,
    EditorDrawToolIndex.sticker,
  ];

  int get _activeRailIndex {
    final idx = _railToolValues.indexOf(_activeDrawTool);
    return idx >= 0 ? idx : 0;
  }

  (IconData, String) get _activeToolDisplay {
    final idx = _activeRailIndex;
    if (idx < _drawToolData.length) return _drawToolData[idx];
    return (Icons.pan_tool_alt_outlined, 'Navigate');
  }

  bool get _canvasCapturesPointer =>
      EditorDrawToolIndex.capturesPointer(_activeDrawTool) ||
      (_activeDrawTool == EditorDrawToolIndex.navigate && _selectedElementId != null);

  bool get _canPanCanvas =>
      _activeDrawTool == EditorDrawToolIndex.navigate &&
      !_isDraggingElementGlobal &&
      _selectedElementId == null;

  // â”€â”€ Computed props â”€â”€
  List<String> get _parts {
    // In set mode (shirt + pants), include both shirt AND pants limb parts
    if (widget.shirtAssetPath != null && widget.pantsAssetPath != null) {
      return const ['Torso', 'Right Arm', 'Left Arm', 'Right Leg', 'Left Leg'];
    }
    return widget.template.activeParts;
  }
  String get _title => widget.template.displayName;
  PartDrawing get _activePartDrawing => _partDrawings[_parts[_activePartIndex]]!;
  /// In SET mode (shirt+pants), canvas is vertically stacked: 585Ã—1128
  /// (shirt 585Ã—559 on top + 10px gap + pants 585Ã—559 on bottom).
  static const double _setGap = 10;
  Size get _uvSize {
    if (widget.shirtAssetPath != null && widget.pantsAssetPath != null) {
      return Size(585, 559 + _setGap + 559); // 585Ã—1128
    }
    return widget.template.uvCanvasSize;
  }

  /// The JS-side clothing mode for the canonical applyClassicTexture API.
  String get _jsMode {
    if (widget.shirtAssetPath != null && widget.pantsAssetPath != null) return 'set';
    switch (widget.template) {
      case ClothingTemplateType.blankShirt: return 'shirt';
      case ClothingTemplateType.blankPants: return 'pants';
      case ClothingTemplateType.blankTShirt: return 'tshirt';
    }
  }

  Color get _activeColor {
    switch (_activeColorSlot) {
      case 1: return _secondaryColor;
      case 2: return _tertiaryColor;
      default: return _selectedColor;
    }
  }

  // â”€â”€ Active toolbar (context-sensitive) â”€â”€
  List<String> _getActiveToolLabels(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_isIn3DMode) return EditorState.clothing3DToolLabels(l);
    if (_selectedElementId != null) return EditorState.elementToolLabels(l);
    return EditorState.clothing2DToolLabels(l);
  }

  List<IconData> get _activeToolIcons {
    if (_isIn3DMode) return EditorState.clothing3DToolIcons;
    if (_selectedElementId != null) return EditorState.elementToolIcons;
    return EditorState.clothing2DToolIcons;
  }

  int get _activeToolIndex {
    if (_isIn3DMode) return _activeToolIndex3D;
    return _activeToolIndex2D;
  }

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId ?? generateProjectId();
    _partDrawings = {for (final part in _parts) part: PartDrawing(partName: part)};
    _layerState.addListener(_onLayerStateChanged);
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) => _autoSaveProject());
    if (widget.projectId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingProject());
    }
  }

  Future<void> _loadExistingProject() async {
    final data = await ProjectRepository.loadProject(_projectId);
    if (data == null || !mounted) return;
    await EditorProjectSerializer.deserializeAsync(data, _partDrawings);
    _layerState.loadLayersFromJson(
      EditorProjectSerializer.layersFromProject(data),
      activeLayerId: data['active_layer_id'] as String?,
    );
    final idx = data['active_part_index'] as int? ?? 0;
    setState(() {
      if (idx >= 0 && idx < _parts.length) _activePartIndex = idx;
    });
    _syncTextureTo3D(event: 'project_load');
  }

  Future<void> _autoSaveProject() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      final projectData = await EditorProjectSerializer.serializeAsync(
        partDrawings: _partDrawings,
        templateType: widget.template.name,
        activePartIndex: _activePartIndex,
        partNames: _parts,
        layers: _layerState.layersToJson(),
        activeLayerId: _layerState.activeLayerId,
        shirtAssetPath: widget.shirtAssetPath,
        pantsAssetPath: widget.pantsAssetPath,
      );
      Uint8List? thumb;
      final atlasB64 = await EditorTextureComposer.composeFullAtlas(
        partDrawings: _partDrawings,
        partNames: _parts,
        jsMode: _jsMode,
      );
      thumb = EditorProjectSerializer.decodeBase64Png(atlasB64);
      await ProjectRepository.saveProject(
        projectId: _projectId,
        name: _title,
        templateType: widget.template.name,
        projectData: projectData,
        thumbnailPng: thumb,
      );
      _lastSavedAt = DateTime.now();
    } catch (e) {
      debugPrint('[auto-save] failed: $e');
    } finally {
      _isSaving = false;
    }
  }

  void _setPreviewExpanded(bool expanded) {
    if (_previewExpanded == expanded) return;
    setState(() => _previewExpanded = expanded);
    _updatePreviewMount();
    debugPrint('[preview-ui] expanded=$expanded');
  }

  void _updatePreviewMount() {
    final shouldMount = _isIn3DMode || _previewExpanded;
    if (shouldMount != _previewMounted) {
      setState(() => _previewMounted = shouldMount);
    }
  }

  void _onLayerStateChanged() {
    // Any layer property change should re-render canvas and sync to 3D
    setState(() {});
    _syncTextureTo3D(event: 'layer_change');
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _autoSaveProject();
    _syncDebounce?.cancel();
    _viewTransform.dispose();
    _layerState.removeListener(_onLayerStateChanged);
    super.dispose();
  }

  /// Fast byte-level checksum â€” FNV-1a 32-bit hash.
  /// Samples every 64th byte for speed (atlas is ~100KB+).
  /// Collision-safe for our use case (same-size atlas images).
  static int _fnv1aHash(Uint8List bytes) {
    const fnvPrime = 0x01000193;
    var hash = 0x811c9dc5;
    final step = (bytes.length > 4096) ? 64 : 1;
    for (var i = 0; i < bytes.length; i += step) {
      hash ^= bytes[i];
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Load pre-designed texture assets, composite shirt+pants into a single
  /// 585Ã—559 UV texture for 2D canvas, and push each layer separately to 3D.
  Future<void> _loadPreDesignedTextures() async {
    try {
      ui.Image? shirtImage;
      ui.Image? pantsImage;

      // Load shirt texture (network URL or local asset)
      if (widget.shirtAssetPath != null) {
        shirtImage = await _loadImageFromPath(widget.shirtAssetPath!);
      }

      // Load pants texture (network URL or local asset)
      if (widget.pantsAssetPath != null) {
        pantsImage = await _loadImageFromPath(widget.pantsAssetPath!);
      }

      if (!mounted) return;
      if (shirtImage == null && pantsImage == null) return;

      // Store originals for per-layer sync in set mode
      _shirtBaseImage = shirtImage;
      _pantsBaseImage = pantsImage;

      // â”€â”€ Composite textures for 2D canvas â”€â”€
      final bool isSet = shirtImage != null && pantsImage != null;
      // SET mode: stack shirt (top) + gap + pants (bottom) = 585Ã—1128
      // Single mode: just one template at 585Ã—559
      final compositeHeight = isSet ? (559 + _setGap + 559) : 559.0;
      final compositeSize = Size(585, compositeHeight);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      if (isSet) {
        // â”€â”€ SET mode: vertical stack â”€â”€
        // Shirt template on top (y=0..558)
        canvas.drawImageRect(
          shirtImage!,
          Rect.fromLTWH(0, 0, shirtImage.width.toDouble(), shirtImage.height.toDouble()),
          const Rect.fromLTWH(0, 0, 585, 559),
          Paint(),
        );
        // Separator line
        canvas.drawRect(
          Rect.fromLTWH(0, 559, 585, _setGap),
          Paint()..color = const Color(0xFF333333),
        );
        // Pants template on bottom (y=569..1127)
        canvas.drawImageRect(
          pantsImage!,
          Rect.fromLTWH(0, 0, pantsImage.width.toDouble(), pantsImage.height.toDouble()),
          Rect.fromLTWH(0, 559 + _setGap, 585, 559),
          Paint(),
        );
      } else if (shirtImage != null) {
        canvas.drawImageRect(
          shirtImage,
          Rect.fromLTWH(0, 0, shirtImage.width.toDouble(), shirtImage.height.toDouble()),
          const Rect.fromLTWH(0, 0, 585, 559),
          Paint(),
        );
      } else if (pantsImage != null) {
        canvas.drawImageRect(
          pantsImage,
          Rect.fromLTWH(0, 0, pantsImage.width.toDouble(), pantsImage.height.toDouble()),
          const Rect.fromLTWH(0, 0, 585, 559),
          Paint(),
        );
      }

      final picture = recorder.endRecording();
      final compositeImage = await picture.toImage(
        compositeSize.width.toInt(),
        compositeSize.height.toInt(),
      );

      if (!mounted) return;

      // â”€â”€ Set as imported image on ALL parts for 2D canvas editing â”€â”€
      setState(() {
        for (final part in _parts) {
          _partDrawings[part]?.importedImage = compositeImage.clone();
        }
      });

      // â”€â”€ Push to 3D viewer: apply pants FIRST, then shirt â”€â”€
      // LowerTorso is in both SHIRT_PARTS and PANTS_PARTS.
      // Pants template has no content at torso UV coordinates â†’ would leave black.
      // By applying shirt LAST, its belt texture fills LowerTorso correctly.
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      if (pantsImage != null) {
        final opToken = _threejsKey.currentState?.beginOp(ViewerOpState.clothingApply) ?? 0;
        final pantsBytes = await pantsImage.toByteData(format: ui.ImageByteFormat.png);
        if (pantsBytes != null && mounted) {
          final pantsB64 = base64Encode(pantsBytes.buffer.asUint8List());
          _threejsKey.currentState?.applyClassicTexture(pantsB64, 'pants', opToken: opToken);
        }
      }

      // Small delay between calls to avoid race conditions
      await Future.delayed(const Duration(milliseconds: 50));

      if (shirtImage != null && mounted) {
        final opToken = _threejsKey.currentState?.beginOp(ViewerOpState.clothingApply) ?? 0;
        final shirtBytes = await shirtImage.toByteData(format: ui.ImageByteFormat.png);
        if (shirtBytes != null && mounted) {
          final shirtB64 = base64Encode(shirtBytes.buffer.asUint8List());
          _threejsKey.currentState?.applyClassicTexture(shirtB64, 'shirt', opToken: opToken);
        }
      }
    } catch (e) {
      debugPrint('Failed to load pre-designed textures: $e');
    }
  }

  /// Load a ui.Image from either a network URL or a local asset path.
  Future<ui.Image?> _loadImageFromPath(String path) async {
    try {
      Uint8List bytes;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        // Network URL (Supabase Storage)
        final response = await http.get(Uri.parse(path));
        if (response.statusCode != 200) {
          debugPrint('Network image load failed ($path): ${response.statusCode}');
          return null;
        }
        bytes = response.bodyBytes;
      } else {
        // Local asset
        final data = await rootBundle.load(path);
        bytes = data.buffer.asUint8List();
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Image load error ($path): $e');
      return null;
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  BUILD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Stack(
            children: [
              // â”€â”€ UV Canvas (visible in 2D mode only) â”€â”€
              if (!_isIn3DMode)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(52, 6, 10, 0),
                    child: _buildUVCanvas(),
                  ),
                ),

              // â”€â”€ ThreeJS Preview (single instance, animated layout) â”€â”€
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                top: _isIn3DMode ? 0 : 12,
                right: _isIn3DMode ? 0 : 14,
                left: _isIn3DMode ? 0 : null,
                bottom: _isIn3DMode ? 0 : null,
                width: _isIn3DMode ? null : (_previewExpanded ? MediaQuery.of(context).size.width - 32 : 100),
                height: _isIn3DMode ? null : (_previewExpanded ? 360 : 130),
                child: _buildPreviewContainer(),
              ),

              // â”€â”€ Mode switcher pill (top-left) â”€â”€
              Positioned(
                top: 12,
                left: 12,
                child: _buildModeSwitcher(),
              ),

              // â”€â”€ 2D tool rail (left) â”€â”€
              if (!_isIn3DMode)
                Positioned(
                  left: 4,
                  top: 56,
                  bottom: 8,
                  child: Editor2DToolRail(
                    tools: _drawToolData,
                    activeIndex: _activeRailIndex,
                    onSelect: _selectDrawTool,
                  ),
                ),

              // â”€â”€ Front/Back toggle (3D mode, bottom-left) â”€â”€
              if (_isIn3DMode)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: _buildFrontBackToggle(),
                ),
            ],
          ),
        ),

        // â”€â”€ Element controls (2D mode, element selected) â”€â”€
        if (!_isIn3DMode && _selectedElementId != null) _buildElementControls(),

        // â”€â”€ Draw controls (brush size, colors) when a drawing tool is active â”€â”€
        if (!_isIn3DMode && EditorDrawToolIndex.capturesPointer(_activeDrawTool))
          EditorDrawControlsPanel(
            activeDrawTool: _activeDrawTool,
            colorPalette: _colorPalette,
            onColorSelected: _setActiveSlotColor,
            brushSize: _brushSize,
            onBrushSizeChanged: (v) => setState(() => _brushSize = v),
            brushOpacity: _brushOpacity,
            onBrushOpacityChanged: (v) => setState(() => _brushOpacity = v),
            gradientControls: _buildGradientControls(),
            shapeControls: _buildShapeControls(),
          ),

        // â”€â”€ Expanded panel content â”€â”€
        if (_isPanelExpanded) _buildActivePanelContent(),

        // â”€â”€ Dynamic bottom toolbar â”€â”€
        _buildDynamicToolbar(),
      ],
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TOP BAR: Home / Undo / Redo / Part chips / DÄ±ÅŸa aktar
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          // Home
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.home_outlined, size: 20, color: AppColors.onSurface),
            ),
          ),
          const SizedBox(width: 6),
          if (!_isIn3DMode) ...[
            _topBarAction(Icons.layers, _openLayerPanel),
            _topBarAction(
              _showPlacementGrid ? Icons.grid_on : Icons.grid_off,
              () => setState(() => _showPlacementGrid = !_showPlacementGrid),
            ),
          ],
          _topBarAction(Icons.undo, _undoStack.isNotEmpty ? _undo : null, enabled: _undoStack.isNotEmpty),
          _topBarAction(Icons.redo, _redoStack.isNotEmpty ? _redo : null, enabled: _redoStack.isNotEmpty),
          const Spacer(),
          // Part chips
          if (!_isIn3DMode)
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _parts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 5),
                  itemBuilder: (context, index) {
                    final isActive = index == _activePartIndex;
                    return GestureDetector(
                      onTap: () {
                        _collapsePreviewIfExpanded('part_switch');
                        setState(() => _activePartIndex = index);
                        // Re-center viewport on part switch
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _centerUvViewport(reason: 'part_switch'));
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: isActive ? null : Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15)),
                          boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 6)] : null,
                        ),
                        child: Center(
                          child: Text(
                            _parts[index],
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isActive ? Colors.white : AppColors.onSurface),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_isIn3DMode)
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  _title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                ),
              ),
            ),
          const SizedBox(width: 8),
          // Export â†’ dropdown with publish options
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85),
                builder: (_) => PublishSheet(
                  designId: _projectId,
                  designName: _title,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.ios_share, size: 14, color: AppColors.onSurface.withValues(alpha: 0.7)),
                  SizedBox(width: 4),
                  Text(AppLocalizations.of(context)!.editorExportButton, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onSurface.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBarAction(IconData icon, VoidCallback? onTap, {bool enabled = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, size: 20, color: enabled ? AppColors.onSurface.withValues(alpha: 0.6) : AppColors.outlineVariant.withValues(alpha: 0.25)),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  MODE SWITCHER (3D / 2D pill)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeBtn('3D', true),
          _modeBtn('2D', false),
        ],
      ),
    );
  }

  Widget _modeBtn(String label, bool is3D) {
    final isActive = _isIn3DMode == is3D;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isIn3DMode = is3D;
          _isPanelExpanded = false;
          if (!is3D) {
            _activeDrawTool = EditorDrawToolIndex.navigate;
            _selectedElementId = null;
            _updatePreviewMount();
          } else {
            _previewMounted = true;
          }
        });
        // Auto-center viewport when entering 2D mode
        if (!is3D) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _centerUvViewport(reason: '2d_mode_entry'));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.outlineVariant,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  FRONT/BACK TOGGLE
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildFrontBackToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _showFrontView = true);
              _threejsKey.currentState?.setViewAngle(0);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _showFrontView ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(AppLocalizations.of(context)!.editorFront, style: TextStyle(
                color: _showFrontView ? Colors.white : AppColors.outlineVariant,
                fontSize: 11, fontWeight: FontWeight.w700,
              )),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _showFrontView = false);
              _threejsKey.currentState?.setViewAngle(180);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: !_showFrontView ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(AppLocalizations.of(context)!.editorBack, style: TextStyle(
                color: !_showFrontView ? Colors.white : AppColors.outlineVariant,
                fontSize: 11, fontWeight: FontWeight.w700,
              )),
            ),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  THREEJS PREVIEW CONTAINER (shared between 3D fullscreen + 2D mini)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildPreviewContainer() {
    final is3D = _isIn3DMode;
    return GestureDetector(
      onTap: is3D || _previewExpanded
          ? null
          : () => _setPreviewExpanded(true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: is3D ? const Color(0xFFF0F0F3) : Colors.white,
          borderRadius: BorderRadius.circular(is3D ? 0 : 14),
          boxShadow: is3D ? null : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
          border: is3D ? null : Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(is3D ? 0 : 14),
          child: Stack(
            children: [
              Positioned.fill(
                child: _previewMounted
                    ? AbsorbPointer(
                        absorbing: !is3D && !_previewExpanded,
                        child: ThreeJSPreview(
                          key: _threejsKey,
                          showControls: is3D || _previewExpanded,
                          onModelReady: () {
                            if (widget.shirtAssetPath != null || widget.pantsAssetPath != null) {
                              _loadPreDesignedTextures();
                              _pendingSync = false;
                            } else if (_pendingSync) {
                              _pendingSync = false;
                              _syncTextureTo3D(event: 'flush');
                            } else {
                              _threejsKey.currentState?.endCurrentOp();
                            }
                          },
                        ),
                      )
                    : ColoredBox(
                        color: const Color(0xFFF0F0F3),
                        child: Center(
                          child: Icon(
                            Icons.view_in_ar,
                            size: 32,
                            color: AppColors.outlineVariant.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
              ),
              // Edge handle — open (◀) when mini, close (▶) when expanded
              if (!is3D) _buildPreviewEdgeHandle(expanded: _previewExpanded),
              // Template label (mini collapsed only)
              if (!is3D && !_previewExpanded)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white.withValues(alpha: 0.95)],
                      ),
                    ),
                    child: Text(_title, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: AppColors.onSurface.withValues(alpha: 0.6)),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  2D UV CANVAS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildUVCanvas() {
    return RepaintBoundary(
      key: _canvasKey,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Capture canvas layout size for fit-to-center calculation.
              // Use post-frame to avoid setState-during-build.
              final newSize = Size(constraints.maxWidth, constraints.maxHeight);
              if (newSize != _uvCanvasLayoutSize) {
                _uvCanvasLayoutSize = newSize;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_uvCanvasLayoutSize == newSize) _centerUvViewport(reason: 'layout_init');
                });
              }
              final bool disableZoom = _activeDrawTool == EditorDrawToolIndex.sticker;
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: _canPanCanvas
                    ? (details) => _handleNavigateTap(details.localPosition, newSize)
                    : null,
                child: InteractiveViewer(
                transformationController: _viewTransform,
                minScale: 0.3,
                maxScale: 8.0,
                panEnabled: _canPanCanvas,
                scaleEnabled: !disableZoom,
                boundaryMargin: const EdgeInsets.all(120),
                child: Stack(

              children: [
                CustomPaint(painter: _DotGridPainter(), size: Size.infinite),
                if (_showPlacementGrid)
                  Positioned.fill(
                    child: CustomPaint(painter: _UVTemplateOutlinePainter(templateType: widget.template)),
                  ),
                Positioned.fill(
                  child: DrawingCanvas(
                    uvSize: _uvSize,
                    partDrawing: _activePartDrawing,
                    activeColor: _activeColor,
                    brushWidth: _brushSize,
                    brushOpacity: _brushOpacity,
                    activeTool: _activeDrawTool,
                    inputEnabled: _canvasCapturesPointer,
                    activeShape: _activeShape,
                    shapeFilled: _shapeFilled,
                    activeGradientType: _activeGradientType,
                    gradientEndColor: _gradientEndColor,
                    activeBlendMode: _activeBlendMode,
                    selectedElementId: _selectedElementId,
                    transformationController: _viewTransform,
                    layers: _layerState.layers,
                    activeLayerId: _layerState.activeLayerId,
                    onInteractionStart: () {
                      _collapsePreviewIfExpanded('canvas_tap');
                    },
                    onElementSelected: (id) {
                      setState(() => _selectedElementId = id);
                      debugPrint('[preview-state] selected=$id mode=${_isIn3DMode ? "3d" : "2d"} expanded=$_previewExpanded');
                    },
                    onStrokeCommitted: () {
                      _undoStack.add(_UndoEntry(partName: _parts[_activePartIndex], strokeIndex: _activePartDrawing.strokes.length - 1));
                      _redoStack.clear();
                      _syncTextureTo3D(event: 'stroke');
                      setState(() {});
                    },
                    onElementChanged: () {
                      _isDraggingElementGlobal = false;
                      _syncTextureTo3D(event: 'drag_end');
                      setState(() {
                        // After moving a sticker/element, stay in hand mode so
                        // the next touch pans/zooms instead of drawing.
                        _activeDrawTool = EditorDrawToolIndex.navigate;
                      });
                    },
                    onElementDragging: () {
                      _isDraggingElementGlobal = true;
                      _syncTextureTo3DLive();
                    },
                  ),
                ),
                // Blank watermark
                if (_activePartDrawing.strokes.isEmpty && _activePartDrawing.elements.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, size: 28, color: AppColors.outlineVariant.withValues(alpha: 0.12)),
                        SizedBox(height: 4),
                        Text(_parts[_activePartIndex], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.outlineVariant.withValues(alpha: 0.15))),
                        SizedBox(height: 2),
                        Text(_getDrawToolHint(), style: TextStyle(fontSize: 9, color: AppColors.outlineVariant.withValues(alpha: 0.15))),
                      ],
                    ),
                  ),
                // UV size badge
                Positioned(
                  bottom: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(6)),
                    child: Text('${_uvSize.width.toInt()}Ã—${_uvSize.height.toInt()} px',
                      style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                // Draw tool badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_activeToolDisplay.$1, size: 11, color: AppColors.primary),
                        SizedBox(width: 3),
                        Text(
                          _activeToolDisplay.$2,
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                // Active layer badge
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: _openLayerPanel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _layerState.isActiveLayerLocked
                            ? AppColors.error.withValues(alpha: 0.12)
                            : AppColors.surfaceContainerLow.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _layerState.isActiveLayerLocked
                              ? AppColors.error.withValues(alpha: 0.3)
                              : AppColors.outlineVariant.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _layerState.isActiveLayerLocked ? Icons.lock : Icons.layers,
                            size: 10,
                            color: _layerState.isActiveLayerLocked ? AppColors.error : AppColors.secondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _layerState.activeLayer?.name ?? 'Base',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: _layerState.isActiveLayerLocked ? AppColors.error : AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
                ),
              ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _getDrawToolHint() {
    final l = AppLocalizations.of(context)!;
    switch (_activeDrawTool) {
      case EditorDrawToolIndex.navigate:
        return l.editorHintNavigate;
      case EditorDrawToolIndex.brush:
        return l.editorHintDraw;
      case EditorDrawToolIndex.fill:
        return l.editorHintFill;
      case EditorDrawToolIndex.eraser:
        return l.editorHintErase;
      case EditorDrawToolIndex.gradient:
        return l.editorHintGradient;
      case EditorDrawToolIndex.shape:
        return l.editorHintShape;
      case EditorDrawToolIndex.sticker:
        return l.editorHintSticker;
      default:
        return l.editorHintNavigate;
    }
  }

  void _handleNavigateTap(Offset localPosition, Size canvasSize) {
    final uvPos = localToUv(localPosition, canvasSize, _uvSize);
    if (uvPos.dx < 0 ||
        uvPos.dy < 0 ||
        uvPos.dx > _uvSize.width ||
        uvPos.dy > _uvSize.height) {
      if (_selectedElementId != null) {
        setState(() => _selectedElementId = null);
      }
      return;
    }
    final hit = findElementAt(_activePartDrawing, uvPos);
    setState(() => _selectedElementId = hit?.id);
  }

  void _selectDrawTool(int railIndex) {
    if (railIndex < 0 || railIndex >= _railToolValues.length) return;
    final tool = _railToolValues[railIndex];
    if (tool == EditorDrawToolIndex.sticker) {
      _openStickerSheet();
      return;
    }
    setState(() {
      _activeDrawTool = tool;
      if (tool == EditorDrawToolIndex.navigate) {
        _selectedElementId = null;
      }
    });
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  ELEMENT CONTROLS (2D mode, element selected)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildElementControls() {
    final element = _activePartDrawing.elements
        .where((e) => e.id == _selectedElementId)
        .firstOrNull;
    if (element == null) return const SizedBox.shrink();

    return ElementControls(
      element: element,
      onCopy: () {
        _clipboard = element.clone();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.editorCopied), duration: const Duration(milliseconds: 800), behavior: SnackBarBehavior.floating),
        );
      },
      onPaste: () {
        if (_clipboard != null) {
          final pasted = _clipboard!.clone();
          pasted.layerId = _layerState.activeLayerId;
          _activePartDrawing.elements.add(pasted);
          setState(() => _selectedElementId = pasted.id);
          _syncTextureTo3D(event: 'paste');
        }
      },
      onDelete: () {
        _activePartDrawing.elements.removeWhere((e) => e.id == _selectedElementId);
        setState(() => _selectedElementId = null);
        _syncTextureTo3D(event: 'delete');
      },
      onFlipH: () {
        setState(() => element.flipH = !element.flipH);
        _syncTextureTo3D(event: 'flip');
      },
      onFlipV: () {
        setState(() => element.flipV = !element.flipV);
        _syncTextureTo3D(event: 'flip');
      },
      onRotateCW: () {
        setState(() => element.rotation += math.pi / 2);
        _syncTextureTo3D(event: 'rotate');
      },
      onRotateCCW: () {
        setState(() => element.rotation -= math.pi / 2);
        _syncTextureTo3D(event: 'rotate');
      },
      onOpacityChanged: (v) {
        setState(() => element.opacity = v);
        _syncTextureTo3D(event: 'opacity');
      },
      onRotationChanged: (v) {
        setState(() => element.rotation = v);
        _syncTextureTo3D(event: 'rotate');
      },
      onScaleChanged: (v) {
        setState(() => element.scale = v);
        _syncTextureTo3D(event: 'scale');
      },
      onBringForward: () {
        final elements = _activePartDrawing.elements;
        final idx = elements.indexWhere((e) => e.id == element.id);
        if (idx >= 0 && idx < elements.length - 1) {
          elements.removeAt(idx);
          elements.add(element); // Move to end (top of z-stack)
          _syncTextureTo3D(event: 'z_order');
          setState(() {});
        }
      },
      onSendBack: () {
        final elements = _activePartDrawing.elements;
        final idx = elements.indexWhere((e) => e.id == element.id);
        if (idx > 0) {
          elements.removeAt(idx);
          elements.insert(0, element); // Move to start (bottom of z-stack)
          _syncTextureTo3D(event: 'z_order');
          setState(() {});
        }
      },
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  DYNAMIC BOTTOM TOOLBAR (context-sensitive)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildDynamicToolbar() {
    final labels = _getActiveToolLabels(context);
    final icons = _activeToolIcons;
    final currentIdx = _activeToolIndex;
    final isElementContext = !_isIn3DMode && _selectedElementId != null;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 8,
        top: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(labels.length, (i) {
          final isSelected = i == currentIdx && _isPanelExpanded;
          return GestureDetector(
            onTap: () => _onToolbarTap(i, isElementContext),
            child: SizedBox(
              width: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(7),
                    decoration: isSelected
                        ? BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: Icon(icons[i],
                      color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                      size: 22,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  void _onToolbarTap(int index, bool isElementContext) {
    if (isElementContext) {
      // Execute element action directly
      _executeElementAction(index);
      return;
    }
    setState(() {
      if (_isIn3DMode) {
        if (_activeToolIndex3D == index) {
          _isPanelExpanded = !_isPanelExpanded;
        } else {
          _activeToolIndex3D = index;
          _isPanelExpanded = true;
        }
      } else {
        if (_activeToolIndex2D == index) {
          _isPanelExpanded = !_isPanelExpanded;
        } else {
          _activeToolIndex2D = index;
          _isPanelExpanded = true;
        }
      }
    });
  }

  void _executeElementAction(int index) {
    final element = _activePartDrawing.elements
        .where((e) => e.id == _selectedElementId)
        .firstOrNull;
    if (element == null) return;

    switch (index) {
      case 0: // Opacity — nudge element opacity
        setState(() {
          element.opacity = (element.opacity + 0.1).clamp(0.05, 1.0);
        });
        _syncTextureTo3D(event: 'opacity');
        break;
      case 1: // Ã–ne
        _bringForward();
        // _bringForward already calls _syncTextureTo3D internally
        break;
      case 2: // Arkaya
        _sendBackward();
        // _sendBackward already calls _syncTextureTo3D internally
        break;
      case 3: // Yatay Ã§evir
        setState(() => element.flipH = !element.flipH);
        _syncTextureTo3D(event: 'flip');
        break;
      case 4: // Dikey Ã§evir
        setState(() => element.flipV = !element.flipV);
        _syncTextureTo3D(event: 'flip');
        break;
      case 5: // Duplicate
        final copy = element.clone();
        copy.layerId = _layerState.activeLayerId;
        _activePartDrawing.elements.add(copy);
        setState(() => _selectedElementId = copy.id);
        _syncTextureTo3D(event: 'duplicate');
        break;
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  ACTIVE PANEL CONTENT (depends on mode + tab)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildActivePanelContent() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.08))),
      ),
      child: _isIn3DMode ? _build3DPanelContent() : _build2DPanelContent(),
    );
  }

  // â”€â”€ 3D Mode Panels â”€â”€
  // Order: Aksesuarlar(0) | Medya(1) | Yapay ZekÃ¢ MedyasÄ±(2) | YÃ¼klemeler(3) | Metin(4)

  Widget _build3DPanelContent() {
    switch (_activeToolIndex3D) {
      case 0: return _buildClothingAccessoriesPanel();
      case 1: return _buildReferenceMediaPanel();
      case 2: return _buildUploadsPanel();
      case 3: return _buildTextPanel();
      case 4: return _buildAvatarPanel();
      default: return const SizedBox.shrink();
    }
  }

  Widget _build2DPanelContent() {
    switch (_activeToolIndex2D) {
      case 0: return _buildClothingTemplatesPanel();
      case 1: return _buildColorPanel();
      case 2: return _buildClothingAccessoriesPanel();
      case 3: return _buildReferenceMediaPanel();
      default: return const SizedBox.shrink();
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  3D PANELS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  /// Åablonlar â€” template info (no switching, per P2 decision)
  Widget _buildClothingTemplatesPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.editorTemplates, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(widget.template.icon, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                      SizedBox(height: 2),
                      Text(widget.template.subtitle, style: TextStyle(fontSize: 11, color: AppColors.outlineVariant)),
                      Text('Roblox: ${widget.template.robloxClassName}', style: TextStyle(fontSize: 10, color: AppColors.outlineVariant)),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renkler â€” color presets + palette
  Widget _buildColorPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.editorColors, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.editorColorApplied), duration: const Duration(milliseconds: 800), behavior: SnackBarBehavior.floating),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check, size: 18, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Preset color circles (large, matching screenshot)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presetColors.map((c) {
              final isSelected = c.value == _clothingBaseColor.value;
              return GestureDetector(
                onTap: () {
                  setState(() => _clothingBaseColor = c);
                  _threejsKey.currentState?.applyClothingColor(c);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : c.withValues(alpha: 0.3),
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)]
                        : [BoxShadow(color: c.withValues(alpha: 0.2), blurRadius: 4)],
                  ),
                  child: isSelected ? const Center(child: Icon(Icons.check, size: 18, color: Colors.white)) : null,
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 14),
          // Full palette row
          Text(AppLocalizations.of(context)!.editorColorPalette, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.outlineVariant)),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _colorPalette.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final c = _colorPalette[i];
                return GestureDetector(
                  onTap: () {
                    setState(() => _clothingBaseColor = c);
                    _threejsKey.currentState?.applyClothingColor(c);
                  },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == const Color(0xFFFFFFFF) ? AppColors.outlineVariant.withValues(alpha: 0.3) : c.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Region color buttons
          Row(
            children: [
              _regionColorBtn(AppLocalizations.of(context)!.editorRegionUpper, 'upper'),
              const SizedBox(width: 8),
              _regionColorBtn(AppLocalizations.of(context)!.editorRegionLower, 'lower'),
              const SizedBox(width: 8),
              _regionColorBtn(AppLocalizations.of(context)!.editorRegionAll, 'all'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _regionColorBtn(String label, String region) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _threejsKey.currentState?.applyRegionColor(region, _clothingBaseColor),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          ),
        ),
      ),
    );
  }

  /// Aksesuarlar â€” sticker/decal placement (3D â†’ UV)
  Widget _buildClothingAccessoriesPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.diamond, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.editorAccessories, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _openStickerSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppColors.actionGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.editorAddSticker, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(AppLocalizations.of(context)!.editorStickerDescription, style: TextStyle(fontSize: 10, color: AppColors.outlineVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Medya — sticker ve galeri yüklemesi
  Widget _buildReferenceMediaPanel() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _openStickerSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.actionGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.editorAddSticker, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickAndUploadReferenceImage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_upload, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.editorUploadImage, style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
          Text(AppLocalizations.of(context)!.editorUploadFromGallery, style: TextStyle(fontSize: 11, color: AppColors.outlineVariant)),
        ],
      ),
    );
  }

  /// Yüklemeler
  Widget _buildUploadsPanel() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _pickAndUploadReferenceImage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.actionGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_upload, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.editorUploadImage, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.editorUploadFromGallery, style: TextStyle(fontSize: 11, color: AppColors.outlineVariant)),
        ],
      ),
    );
  }

  /// Metin
  Widget _buildTextPanel() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () async {
              final controller = TextEditingController();
              final result = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(AppLocalizations.of(context)!.editorAddText),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(hintText: AppLocalizations.of(context)!.editorTextHint),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.commonCancel)),
                    TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(AppLocalizations.of(context)!.editorAddButton)),
                  ],
                ),
              );
              if (result != null && result.isNotEmpty) {
                final element = CanvasElement(
                  id: 'text_${DateTime.now().millisecondsSinceEpoch}',
                  text: result,
                  textStyle: TextStyle(fontSize: 24, color: _activeColor, fontWeight: FontWeight.w700),
                  position: Offset(_uvSize.width / 2, _uvSize.height / 2),
                  layerId: _layerState.activeLayerId,
                );
                _activePartDrawing.elements.add(element);
                _syncTextureTo3D();
                setState(() => _selectedElementId = element.id);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.actionGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.title, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.editorAddText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.editorTextDescription, style: TextStyle(fontSize: 11, color: AppColors.outlineVariant)),
        ],
      ),
    );
  }

  /// Avatar â€” body type selector
  Widget _buildAvatarPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.editorAvatarSettings,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'R15 Classic Block Mannequin',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                ),
                SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context)!.editorHelpPreviewTip,
                  style: TextStyle(fontSize: 11, color: AppColors.outlineVariant, height: 1.4),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          GestureDetector(
            onTap: () => _threejsKey.currentState?.resetCamera(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.center_focus_strong, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.editorHintNavigate,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// YardÄ±m
  Widget _buildHelpPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.editorHelp, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _helpRow(Icons.touch_app, AppLocalizations.of(context)!.editorHelpDrawTip),
          _helpRow(Icons.pan_tool, AppLocalizations.of(context)!.editorHelpStickerTip),
          _helpRow(Icons.zoom_in, AppLocalizations.of(context)!.editorHelpZoomTip),
          _helpRow(Icons.view_in_ar, AppLocalizations.of(context)!.editorHelpPreviewTip),
          _helpRow(Icons.palette, AppLocalizations.of(context)!.editorHelpColorTip),
          _helpRow(Icons.sync, AppLocalizations.of(context)!.editorHelpSyncTip),
        ],
      ),
    );
  }

  Widget _helpRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: AppColors.onSurface))),
        ],
      ),
    );
  }

  // â”€â”€ Gradient sub-controls â”€â”€
  Widget _buildGradientControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(AppLocalizations.of(context)!.editorGradientLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.outlineVariant)),
          SizedBox(width: 6),
          _miniChip(AppLocalizations.of(context)!.editorGradientLinear, _activeGradientType == GradientFillType.linear,
              () => setState(() => _activeGradientType = GradientFillType.linear)),
          const SizedBox(width: 4),
          _miniChip(AppLocalizations.of(context)!.editorGradientRadial, _activeGradientType == GradientFillType.radial,
              () => setState(() => _activeGradientType = GradientFillType.radial)),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context)!.editorGradientEnd, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.outlineVariant)),
          const SizedBox(width: 4),
          ...List.generate(6, (i) {
            final colors = [
              Colors.white, Colors.black, const Color(0xFF2196F3),
              const Color(0xFF4CAF50), const Color(0xFFFF9800), const Color(0xFF9C27B0),
            ];
            final c = colors[i];
            final isSelected = c.value == _gradientEndColor.value;
            return GestureDetector(
              onTap: () => setState(() => _gradientEndColor = c),
              child: Container(
                width: 16, height: 16,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: isSelected ? 2 : 1,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // â”€â”€ Shape sub-controls â”€â”€
  Widget _buildShapeControls() {
    final shapes = [
      (ShapeType.rectangle, Icons.crop_square, 'Kare'),
      (ShapeType.circle, Icons.circle_outlined, 'Daire'),
      (ShapeType.triangle, Icons.change_history, 'ÃœÃ§gen'),
      (ShapeType.line, Icons.remove, 'Ã‡izgi'),
      (ShapeType.star, Icons.star_outline, 'YÄ±ldÄ±z'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          ...shapes.map((s) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => setState(() => _activeShape = s.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: _activeShape == s.$1 ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFF0F0F3),
                  borderRadius: BorderRadius.circular(8),
                  border: _activeShape == s.$1 ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.$2, size: 12, color: _activeShape == s.$1 ? AppColors.primary : AppColors.outlineVariant),
                    SizedBox(width: 2),
                    Text(s.$3, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                        color: _activeShape == s.$1 ? AppColors.primary : AppColors.onSurface)),
                  ],
                ),
              ),
            ),
          )),
          const Spacer(),
          _miniChip(AppLocalizations.of(context)!.editorShapeFilled, _shapeFilled, () => setState(() => _shapeFilled = true)),
          const SizedBox(width: 4),
          _miniChip(AppLocalizations.of(context)!.editorShapeOutline, !_shapeFilled, () => setState(() => _shapeFilled = false)),
        ],
      ),
    );
  }

  Widget _miniChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFF0F0F3),
          borderRadius: BorderRadius.circular(6),
          border: isActive ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1) : null,
        ),
        child: Text(label, style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: isActive ? AppColors.primary : AppColors.onSurface,
        )),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LAYER ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  void _openLayerPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: LayerPanel(
                  editorState: _layerState,
                  onLayerRemoved: _reassignLayerContent,
                  onChanged: () {
                    setState(() {});
                    _syncTextureTo3D(event: 'layer_panel');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reassignLayerContent(String removedLayerId) {
    for (final part in _partDrawings.values) {
      for (int i = 0; i < part.strokes.length; i++) {
        if (part.strokes[i].layerId == removedLayerId) {
          part.strokes[i] = part.strokes[i].copyWith(layerId: EditorState.baseLayerId);
        }
      }
      for (final element in part.elements) {
        if (element.layerId == removedLayerId) {
          element.layerId = EditorState.baseLayerId;
        }
      }
    }
    _syncTextureTo3D(event: 'layer_removed');
  }

  void _pickColor(int slot) {
    setState(() => _activeColorSlot = slot);
  }

  void _setActiveSlotColor(Color color) {
    setState(() {
      switch (_activeColorSlot) {
        case 0: _selectedColor = color; break;
        case 1: _secondaryColor = color; break;
        case 2: _tertiaryColor = color; break;
      }
    });
  }

  void _bringForward() {
    if (_selectedElementId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.editorBringToFront), duration: const Duration(milliseconds: 600), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final idx = _activePartDrawing.elements.indexWhere((e) => e.id == _selectedElementId);
    if (idx >= 0 && idx < _activePartDrawing.elements.length - 1) {
      final el = _activePartDrawing.elements.removeAt(idx);
      _activePartDrawing.elements.insert(idx + 1, el);
      _syncTextureTo3D(event: 'layer');
      setState(() {});
    }
  }

  void _sendBackward() {
    if (_selectedElementId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.editorSendToBack), duration: const Duration(milliseconds: 600), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final idx = _activePartDrawing.elements.indexWhere((e) => e.id == _selectedElementId);
    if (idx > 0) {
      final el = _activePartDrawing.elements.removeAt(idx);
      _activePartDrawing.elements.insert(idx - 1, el);
      _syncTextureTo3D(event: 'layer');
      setState(() {});
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  2D â†’ 3D TEXTURE SYNC (with in-flight protection + ready guard + log contract)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  static const _shirtRegions = [
    Rect.fromLTWH(0, 0, 105, 219),
    Rect.fromLTWH(105, 0, 220, 219),
    Rect.fromLTWH(325, 0, 105, 219),
    Rect.fromLTWH(430, 0, 155, 219),
  ];

  static const _pantsRegions = [
    Rect.fromLTWH(0, 219, 105, 340),
    Rect.fromLTWH(105, 219, 115, 340),
    Rect.fromLTWH(220, 219, 105, 340),
    Rect.fromLTWH(325, 219, 105, 340),
  ];

  List<Rect> get _activeUVRegions {
    // For pre-designed sets (both shirt + pants), use combined UV regions
    if (widget.shirtAssetPath != null && widget.pantsAssetPath != null) {
      return [..._shirtRegions, ..._pantsRegions];
    }
    switch (widget.template) {
      case ClothingTemplateType.blankShirt:
        return _shirtRegions;
      case ClothingTemplateType.blankPants:
        return _pantsRegions;
      case ClothingTemplateType.blankTShirt:
        return [const Rect.fromLTWH(0, 0, 128, 128)];
    }
  }

  /// Standard sync â€” 100ms debounce, used for stroke commit, element actions, etc.
  void _syncTextureTo3D({String event = 'unknown'}) {
    // Ready guard
    if (_threejsKey.currentState?.isModelReady != true) {
      debugPrint('[preview-sync] event=$event elementId=$_selectedElementId result=queued');
      _pendingSync = true;
      return;
    }

    // Reset hash state so live-sync worker won't skip the updated atlas
    _lastShirtHash = 0;
    _lastPantsHash = 0;
    _lastFullHash = 0;

    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 100), () async {
      if (!mounted) return;
      final sw = Stopwatch()..start();
      final opToken = _threejsKey.currentState?.beginOp(ViewerOpState.textureSyncFinal) ?? 0;
      try {
        if (_jsMode == 'set') {
          // Set mode: apply pants FIRST (legs), then shirt (torso+arms).
          final pantsAtlas = await EditorTextureComposer.composeLayerAtlas(
            partDrawings: _partDrawings,
            layerParts: const ['Torso', 'Right Leg', 'Left Leg'],
            baseImage: _pantsBaseImage,
            layerState: _layerState,
            jsMode: _jsMode,
            setGap: _setGap,
          );
          if (pantsAtlas != null && mounted) {
            _threejsKey.currentState?.applyClassicTexture(pantsAtlas, 'pants', opToken: opToken);
          }
          await Future.delayed(const Duration(milliseconds: 30));
          final shirtAtlas = await EditorTextureComposer.composeLayerAtlas(
            partDrawings: _partDrawings,
            layerParts: const ['Torso', 'Right Arm', 'Left Arm'],
            baseImage: _shirtBaseImage,
            layerState: _layerState,
            jsMode: _jsMode,
            setGap: _setGap,
          );
          if (shirtAtlas != null && mounted) {
            _threejsKey.currentState?.applyClassicTexture(shirtAtlas, 'shirt', opToken: opToken);
          }
          debugPrint('[preview-sync] event=$event elementId=$_selectedElementId elapsedMs=${sw.elapsedMilliseconds} result=ok_set');
        } else {
          final base64Str = await EditorTextureComposer.composeFullAtlas(
            partDrawings: _partDrawings,
            partNames: _parts,
            jsMode: _jsMode,
          );
          if (base64Str != null && mounted) {
            _threejsKey.currentState?.applyClassicTexture(base64Str, _jsMode, opToken: opToken);
            debugPrint('[preview-sync] event=$event elementId=$_selectedElementId elapsedMs=${sw.elapsedMilliseconds} result=ok');
          }
        }
      } catch (e) {
        debugPrint('[preview-sync] event=$event elapsedMs=${sw.elapsedMilliseconds} result=error error=$e');
        _threejsKey.currentState?.endOp(opToken);
      }
    });
  }

  /// Live sync â€” latest-wins queue, zero debounce, stale-seq protected.
  ///
  /// Every call from [onElementDragging] fires immediately (no Timer cancel/restart).
  /// The worker picks up the latest pending frame as soon as the previous compose
  /// finishes. Stale results are discarded via seq comparison.
  void _syncTextureTo3DLive() {
    // Ready guard
    if (_threejsKey.currentState?.isModelReady != true) {
      debugPrint('[live-sync] request seq=? queued=true inFlight=false [model_not_ready]');
      _pendingSync = true;
      return;
    }

    final mySeq = ++_liveSyncSeq;
    final isSticker = _selectedElementId?.startsWith('sticker_') ?? false;
    if (isSticker) {
      debugPrint('[sticker-sync] phase=live seq=$mySeq dropped=false');
    }
    debugPrint('[live-sync] request seq=$mySeq queued=$_liveSyncLatestPending inFlight=$_liveSyncWorkerActive');

    if (_liveSyncWorkerActive) {
      // Worker is busy â€” just mark that a newer frame is waiting.
      // The worker will pick it up when done.
      _liveSyncLatestPending = true;
      return;
    }

    // No active worker â€” start one immediately (no debounce).
    _liveSyncLatestPending = false;
    _liveSyncWorkerActive  = true;
    _runLiveSyncWorker(mySeq);
  }

  /// Async worker that composes the atlas and pushes it to JS.
  /// Loops until no pending frames remain (draining the latest-wins queue).
  /// Includes FNV-1a hash skip and adaptive quality.
  Future<void> _runLiveSyncWorker(int startSeq) async {
    int seq = startSeq;
    while (true) {
      if (!mounted) break;
      final sw = Stopwatch()..start();
      debugPrint('[live-sync] compose_start seq=$seq');

      String? base64Str;
      try {
        base64Str = await EditorTextureComposer.composeFullAtlas(
          partDrawings: _partDrawings,
          partNames: _parts,
          jsMode: _jsMode,
        );
      } catch (e) {
        debugPrint('[live-sync] compose_error seq=$seq error=$e');
      }

      final composeMs = sw.elapsedMilliseconds;
      debugPrint('[live-sync] compose_done seq=$seq ms=$composeMs');

      if (base64Str != null && mounted) {
        if (seq < _liveSyncSeq && _liveSyncLatestPending) {
          debugPrint('[live-sync] dropped_stale seq=$seq current=$_liveSyncSeq');
        } else {
          debugPrint('[live-sync] js_apply_start seq=$seq');
          if (_jsMode == 'set') {
            // Set mode: apply pants FIRST (legs), then shirt (torso+arms).
            final opToken = _threejsKey.currentState?.beginOp(ViewerOpState.textureSyncLive) ?? 0;
            final pantsAtlas = await EditorTextureComposer.composeLayerAtlas(
              partDrawings: _partDrawings,
              layerParts: const ['Torso', 'Right Leg', 'Left Leg'],
              baseImage: _pantsBaseImage,
              layerState: _layerState,
              jsMode: _jsMode,
              setGap: _setGap,
            );
            if (pantsAtlas != null && mounted) {
              // FNV-1a hash skip for pants
              final pantsBytes = base64Decode(pantsAtlas);
              final pantsHash = _fnv1aHash(Uint8List.fromList(pantsBytes));
              if (pantsHash != _lastPantsHash) {
                _lastPantsHash = pantsHash;
                _threejsKey.currentState?.applyClassicTexture(pantsAtlas, 'pants', opToken: opToken);
              } else {
                debugPrint('[perf] apply skipped reason=hash_same layer=pants');
              }
            }
            await Future.delayed(const Duration(milliseconds: 30));
            final shirtAtlas = await EditorTextureComposer.composeLayerAtlas(
              partDrawings: _partDrawings,
              layerParts: const ['Torso', 'Right Arm', 'Left Arm'],
              baseImage: _shirtBaseImage,
              layerState: _layerState,
              jsMode: _jsMode,
              setGap: _setGap,
            );
            if (shirtAtlas != null && mounted) {
              // FNV-1a hash skip for shirt
              final shirtBytes = base64Decode(shirtAtlas);
              final shirtHash = _fnv1aHash(Uint8List.fromList(shirtBytes));
              if (shirtHash != _lastShirtHash) {
                _lastShirtHash = shirtHash;
                _threejsKey.currentState?.applyClassicTexture(shirtAtlas, 'shirt', opToken: opToken);
              } else {
                debugPrint('[perf] apply skipped reason=hash_same layer=shirt');
              }
            }
          } else {
            // Non-set mode: single atlas
            final opToken = _threejsKey.currentState?.beginOp(ViewerOpState.textureSyncLive) ?? 0;
            final fullBytes = base64Decode(base64Str);
            final fullHash = _fnv1aHash(Uint8List.fromList(fullBytes));
            if (fullHash != _lastFullHash) {
              _lastFullHash = fullHash;
              _threejsKey.currentState?.applyClassicTexture(base64Str, _jsMode, opToken: opToken);
            } else {
              debugPrint('[perf] apply skipped reason=hash_same layer=full');
              _threejsKey.currentState?.endOp(opToken);
            }
          }
          debugPrint('[live-sync] js_apply_done seq=$seq ms=${sw.elapsedMilliseconds}');
        }
      }

      // Check if a new frame arrived while we were composing
      if (_liveSyncLatestPending && mounted) {
        _liveSyncLatestPending = false;
        seq = _liveSyncSeq; // pick up the latest seq
        debugPrint('[live-sync] request seq=$seq queued=false inFlight=true [loop_continue]');
        continue;
      }

      // No pending â€” worker done
      break;
    }
    _liveSyncWorkerActive = false;
  }

  // â”€â”€â”€ Preview collapse helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Collapses the 3D mini preview card and logs the reason.
  /// Only fires in 2D mode â€” 3D full-screen mode is unaffected.
  void _collapsePreviewIfExpanded(String reason) {
    if (!_isIn3DMode && _previewExpanded) {
      _setPreviewExpanded(false);
      debugPrint('[preview-ui] collapsed reason=$reason');
    }
  }

  /// Left-edge tab: chevron opens mini 3D preview, chevron closes when expanded.
  Widget _buildPreviewEdgeHandle({required bool expanded}) {
    return Positioned(
      left: -1,
      top: 0,
      bottom: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => _setPreviewExpanded(!expanded),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 20,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
              ],
            ),
            child: Icon(
              expanded ? Icons.chevron_right : Icons.chevron_left,
              size: 14,
              color: AppColors.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// Fits the UV canvas to the centre of the [InteractiveViewer] viewport.
  ///
  /// Called on:
  ///   - 2D mode entry
  ///   - Part chip switch
  ///   - Sticker add
  ///   - First layout (LayoutBuilder size captured)
  ///
  /// Formula:
  ///   scale = min(viewW / contentW, viewH / contentH) * 0.92
  ///   translateX = (viewW - contentW * scale) / 2
  ///   translateY = (viewH - contentH * scale) / 2
  void _centerUvViewport({String reason = 'manual', bool isRetry = false}) {
    if (!mounted) return;
    final viewSize = _uvCanvasLayoutSize;
    if (viewSize == Size.zero) {
      // Layout hasn't been measured yet. Retry once after next frame.
      if (!isRetry) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _centerUvViewport(reason: reason, isRetry: true);
        });
      }
      return;
    }
    final contentW = _uvSize.width;
    final contentH = _uvSize.height;
    final scaleX = viewSize.width  / contentW;
    final scaleY = viewSize.height / contentH;
    final scale  = (scaleX < scaleY ? scaleX : scaleY) * 0.92;
    final tx = (viewSize.width  - contentW * scale) / 2;
    final ty = (viewSize.height - contentH * scale) / 2;
    final m = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
    _viewTransform.value = m;
    debugPrint('[viewport-center] reason=$reason scale=${scale.toStringAsFixed(3)} tx=${tx.toStringAsFixed(1)} ty=${ty.toStringAsFixed(1)}');
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  ACTIONS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  void _undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    final drawing = _partDrawings[entry.partName];
    if (drawing != null && drawing.strokes.isNotEmpty) {
      final removed = drawing.strokes.removeLast();
      _redoStack.add(_UndoEntry(partName: entry.partName, strokeIndex: entry.strokeIndex, removedStroke: removed));
    }
    _syncTextureTo3D(event: 'undo');
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final entry = _redoStack.removeLast();
    final drawing = _partDrawings[entry.partName];
    if (drawing != null && entry.removedStroke != null) {
      drawing.strokes.add(entry.removedStroke!);
      _undoStack.add(_UndoEntry(partName: entry.partName, strokeIndex: drawing.strokes.length - 1));
    }
    _syncTextureTo3D(event: 'redo');
    setState(() {});
  }

  void _clearCanvas() {
    _activePartDrawing.strokes.clear();
    _activePartDrawing.elements.clear();
    _undoStack.clear();
    _redoStack.clear();
    _selectedElementId = null;
    _syncTextureTo3D(event: 'clear');
    setState(() {});
  }

  void _openStickerSheet() {
    final activePart = _parts[_activePartIndex];
    // Use the current view state to determine face, not part name heuristic.
    // _showFrontView is the authoritative face toggle â€” when user sees front, sticker goes to front.
    String defaultFace = _showFrontView ? 'front' : 'back';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StickerSheet(
        activePartName: activePart,
        activePartFace: defaultFace,
        uvCanvasSize: _uvSize,
        onStickerSelected: (element) {
          element.layerId = _layerState.activeLayerId;
          // UV-NATIVE: Sticker position from _getFaceAwareCenter is already in UV space (585Ã—559).
          // Canvas now renders in UV space via FittedBox â€” no conversion needed.
          // Atlas compose uses sx=1.0 since sourceCanvasSize = uvSize.
          final drawing = _activePartDrawing;
          drawing.sourceCanvasSize ??= _uvSize;
          debugPrint('[sticker-coord] UV-native pos=(${element.position.dx.toStringAsFixed(1)},${element.position.dy.toStringAsFixed(1)}) uvSize=$_uvSize');
          drawing.elements.add(element);
          // Immediate sync so mini preview shows the sticker right away
          _syncTextureTo3D(event: 'sticker_add');
          debugPrint('[sticker-select] elementId=${element.id} hit=spawn preserved=true');
          // Real verification: log atlas position and expected UV region
          // Torso front atlas: x=231..361, back atlas: x=427..557
          final atlasX = element.position.dx;
          final inFrontRegion = atlasX >= 200 && atlasX <= 380;
          final inBackRegion = atlasX >= 400 && atlasX <= 570;
          final actualRegion = inFrontRegion ? 'front' : (inBackRegion ? 'back' : 'ambiguous');
          debugPrint('[front-back-truth] elementId=${element.id} '
              'targetFace=${element.targetFace} '
              'atlasX=${atlasX.toStringAsFixed(1)} '
              'atlasRegion=$actualRegion '
              'viewState=${_showFrontView ? "front" : "back"} '
              'faceMatchesRegion=${element.targetFace == actualRegion} '
              'part=$activePart');
          _collapsePreviewIfExpanded('part_switch');
          setState(() {
            _selectedElementId = element.id;
            _activeDrawTool = EditorDrawToolIndex.navigate;
            if (_isIn3DMode) {
              _isIn3DMode = false;
              _isPanelExpanded = false;
            }
          });
          // Center viewport after sticker is added so user can see it
          WidgetsBinding.instance.addPostFrameCallback((_) => _centerUvViewport(reason: 'sticker_add'));
        },
      ),
    );
  }

  Future<void> _pickAndUploadReferenceImage() async {
    final result = await ReferenceImageUploadService.pickAndUpload();
    if (!mounted) return;
    if (result == null) return;

    try {
      final codec = await ui.instantiateImageCodec(result.bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _activePartDrawing.importedImage = frame.image;
        _selectedElementId = null;
      });
      _syncTextureTo3D(event: 'upload');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.imageUploadSuccess),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('[upload] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.editorExportFailed('$e')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportPNG() async {
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(AppLocalizations.of(context)!.editorExportedPng(_uvSize.width.toInt().toString(), _uvSize.height.toInt().toString(), (byteData.lengthInBytes / 1024).toStringAsFixed(1))),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.editorExportFailed(e.toString())), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

/// Undo entry with optional removed stroke for redo support.
class _UndoEntry {
  final String partName;
  final int strokeIndex;
  final DrawStroke? removedStroke;
  _UndoEntry({required this.partName, required this.strokeIndex, this.removedStroke});
}

/// Dot grid painter for the editor canvas background.
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8D8D8)
      ..style = PaintingStyle.fill;
    const spacing = 14.0;
    const dotRadius = 1.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}

/// UV Template outline painter â€” draws the orange bounding outline
/// of the active clothing template on top of the dot grid,
/// matching the Roblox classic clothing UV layout.
class _UVTemplateOutlinePainter extends CustomPainter {
  final ClothingTemplateType templateType;
  _UVTemplateOutlinePainter({required this.templateType});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF6A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw a simplified outline of the UV template
    // scaled to fit the canvas dimensions
    final scaleX = size.width * 0.8;
    final scaleY = size.height * 0.8;
    final offsetX = size.width * 0.1;
    final offsetY = size.height * 0.1;

    // Normalized rects for the template regions
    List<Rect> regions;
    switch (templateType) {
      case ClothingTemplateType.blankShirt:
        regions = const [Rect.fromLTWH(0, 0, 1, 0.39)];
        break;
      case ClothingTemplateType.blankPants:
        regions = const [Rect.fromLTWH(0, 0.39, 1, 0.61)];
        break;
      case ClothingTemplateType.blankTShirt:
        regions = const [Rect.fromLTWH(0.2, 0.2, 0.6, 0.6)];
        break;
    }

    for (final r in regions) {
      final rect = Rect.fromLTWH(
        offsetX + r.left * scaleX,
        offsetY + r.top * scaleY,
        r.width * scaleX,
        r.height * scaleY,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );

      // Corner handles
      final handlePaint = Paint()
        ..color = const Color(0xFFFF6A1A)
        ..style = PaintingStyle.fill;
      const handleR = 4.0;
      for (final corner in [
        rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight,
      ]) {
        canvas.drawCircle(corner, handleR, handlePaint);
      }

      // Midpoint handles
      final midPaint = Paint()
        ..color = const Color(0xFFFF6A1A)
        ..style = PaintingStyle.fill;
      const midR = 3.0;
      canvas.drawCircle(Offset(rect.center.dx, rect.top), midR, midPaint);
      canvas.drawCircle(Offset(rect.center.dx, rect.bottom), midR, midPaint);
      canvas.drawCircle(Offset(rect.left, rect.center.dy), midR, midPaint);
      canvas.drawCircle(Offset(rect.right, rect.center.dy), midR, midPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UVTemplateOutlinePainter old) =>
      old.templateType != templateType;
}
