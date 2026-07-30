import 'package:flutter/material.dart';

// ─── Layer Model ────────────────────────────────────────────────────────────

class EditorLayer {
  final String id;
  final String name;
  final IconData icon;
  bool isVisible;
  bool isLocked;
  double opacity;
  String blendMode; // 'normal', 'multiply', 'screen', 'overlay'

  EditorLayer({
    required this.id,
    required this.name,
    required this.icon,
    this.isVisible = true,
    this.isLocked = false,
    this.opacity = 1.0,
    this.blendMode = 'normal',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon_code_point': icon.codePoint,
        'is_visible': isVisible,
        'is_locked': isLocked,
        'opacity': opacity,
        'blend_mode': blendMode,
      };

  static EditorLayer fromJson(Map<String, dynamic> json) {
    return EditorLayer(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Layer',
      icon: IconData(
        json['icon_code_point'] as int? ?? Icons.layers.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      isVisible: json['is_visible'] as bool? ?? true,
      isLocked: json['is_locked'] as bool? ?? false,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      blendMode: json['blend_mode'] as String? ?? 'normal',
    );
  }
}

// ─── Central Editor State ───────────────────────────────────────────────────

class EditorState extends ChangeNotifier {
  static const String baseLayerId = 'base';

  int activeToolIndex = 0;

  // ── Classic Clothing 3D Mode toolbar (4 tabs) ──
  static List<String> clothing3DToolLabels(dynamic l) => [
        l.editorAccessories,
        l.editorMedia,
        l.editorUploadImage,
        l.editorAddText,
        l.editorAvatarSettings,
      ];
  static const clothing3DToolIcons = [
    Icons.diamond,
    Icons.perm_media,
    Icons.cloud_upload_outlined,
    Icons.title,
    Icons.person_outline,
  ];

  // ── Classic Clothing 2D/UV Mode toolbar (4 tabs) ──
  static List<String> clothing2DToolLabels(dynamic l) => [
        l.editorTemplates,
        l.colorPickerTitle,
        l.editorAccessories,
        l.editorMedia,
      ];
  static const clothing2DToolIcons = [
    Icons.dashboard_customize,
    Icons.palette,
    Icons.diamond,
    Icons.perm_media,
  ];

  // ── Context toolbar: element selected in 2D mode ──
  static List<String> elementToolLabels(dynamic l) => [
        l.clothingEditorOpacity,
        l.clothingEditorBringForward,
        l.clothingEditorSendBackward,
        l.elementControlsFlipH,
        l.elementControlsFlipV,
        l.elementControlsCopy,
      ];
  static const elementToolIcons = [
    Icons.opacity,
    Icons.flip_to_front,
    Icons.flip_to_back,
    Icons.flip,
    Icons.swap_vert,
    Icons.copy,
  ];

  void setActiveTool(int index) {
    activeToolIndex = index;
    notifyListeners();
  }

  // ── Viewport State ──
  bool is3DMode = true;

  // ── Layers ──
  final List<EditorLayer> layers = [
    EditorLayer(id: baseLayerId, name: 'Base', icon: Icons.layers),
  ];

  /// Currently active layer — new strokes/elements are assigned to this layer.
  String _activeLayerId = baseLayerId;
  String get activeLayerId => _activeLayerId;

  EditorLayer? get activeLayer =>
      layers.where((l) => l.id == _activeLayerId).firstOrNull;

  bool get isActiveLayerLocked => activeLayer?.isLocked ?? false;

  void setActiveLayer(String layerId) {
    if (!layers.any((l) => l.id == layerId)) return;
    _activeLayerId = layerId;
    notifyListeners();
  }

  void toggleLayerVisibility(int index) {
    if (index < 0 || index >= layers.length) return;
    layers[index].isVisible = !layers[index].isVisible;
    notifyListeners();
  }

  void toggleLayerLock(int index) {
    if (index < 0 || index >= layers.length) return;
    layers[index].isLocked = !layers[index].isLocked;
    notifyListeners();
  }

  void reorderLayers(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= layers.length) return;
    if (newIndex > oldIndex) newIndex--;
    final item = layers.removeAt(oldIndex);
    layers.insert(newIndex, item);
    notifyListeners();
  }

  String addLayer(String name, IconData icon) {
    final id = 'layer_${DateTime.now().millisecondsSinceEpoch}';
    layers.add(EditorLayer(id: id, name: name, icon: icon));
    _activeLayerId = id;
    notifyListeners();
    return id;
  }

  /// Returns removed layer id, or null if removal was blocked.
  String? removeLayer(int index) {
    if (index < 0 || index >= layers.length) return null;
    if (layers.length <= 1) return null;
    final removed = layers[index];
    if (removed.id == baseLayerId) return null;

    layers.removeAt(index);
    if (_activeLayerId == removed.id) {
      _activeLayerId = layers.last.id;
    }
    notifyListeners();
    return removed.id;
  }

  void loadLayersFromJson(List<dynamic>? json, {String? activeLayerId}) {
    layers.clear();
    if (json == null || json.isEmpty) {
      layers.add(EditorLayer(id: baseLayerId, name: 'Base', icon: Icons.layers));
    } else {
      for (final item in json) {
        if (item is Map<String, dynamic>) {
          layers.add(EditorLayer.fromJson(item));
        }
      }
      if (!layers.any((l) => l.id == baseLayerId)) {
        layers.insert(
          0,
          EditorLayer(id: baseLayerId, name: 'Base', icon: Icons.layers),
        );
      }
    }
    if (activeLayerId != null && layers.any((l) => l.id == activeLayerId)) {
      _activeLayerId = activeLayerId;
    } else {
      _activeLayerId = layers.last.id;
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> layersToJson() =>
      layers.map((l) => l.toJson()).toList();

  // ── Undo / Redo ──
  final List<String> _undoStack = ['Initial state'];
  int _undoPointer = 0;

  bool get canUndo => _undoPointer > 0;
  bool get canRedo => _undoPointer < _undoStack.length - 1;
  String get currentAction => _undoStack[_undoPointer];

  void pushAction(String action) {
    if (_undoPointer < _undoStack.length - 1) {
      _undoStack.removeRange(_undoPointer + 1, _undoStack.length);
    }
    _undoStack.add(action);
    _undoPointer++;
    notifyListeners();
  }

  String? undo() {
    if (!canUndo) return null;
    _undoPointer--;
    notifyListeners();
    return _undoStack[_undoPointer];
  }

  String? redo() {
    if (!canRedo) return null;
    _undoPointer++;
    notifyListeners();
    return _undoStack[_undoPointer];
  }

  // ── Draw Tool State ──
  double brushSize = 0.5;
  double brushOpacity = 1.0;
  Color brushColor = const Color(0xFFFF6A1A);
  bool isErasing = false;

  void setBrushSize(double v) {
    brushSize = v;
    notifyListeners();
  }

  void setBrushOpacity(double v) {
    brushOpacity = v;
    notifyListeners();
  }

  void setBrushColor(Color c) {
    brushColor = c;
    notifyListeners();
  }

  void toggleEraser() {
    isErasing = !isErasing;
    notifyListeners();
  }

  // ── Text Tool State ──
  String textContent = '';
  double textSize = 24;
  Color textColor = Colors.white;
  String textFont = 'Default';
  TextAlign textAlign = TextAlign.center;

  void setTextContent(String v) {
    textContent = v;
    notifyListeners();
  }

  void setTextSize(double v) {
    textSize = v;
    notifyListeners();
  }

  void setTextColor(Color c) {
    textColor = c;
    notifyListeners();
  }

  void setTextFont(String f) {
    textFont = f;
    notifyListeners();
  }

  void setTextAlign(TextAlign a) {
    textAlign = a;
    notifyListeners();
  }

  // ── Published State ──
  bool isPublished = false;
  bool isSavedPrivate = false;

  // ══════════════════════════════════════════════════════════════════════════
  // Text presets
  // ══════════════════════════════════════════════════════════════════════════

  static const demoTexts = <String>[
    'ROBLOX',
    'CREW',
    '#1 PLAYER',
    'GG',
    'MVP',
    'PRO',
    'LEGEND',
    'NOOB',
    'BEAST MODE',
    'VIP',
  ];
  static const demoFonts = [
    'Default',
    'Bold Impact',
    'Pixel Art',
    'Futuristic',
    'Hand Drawn',
    'Graffiti',
    'Neon',
    'Comic',
  ];
}
