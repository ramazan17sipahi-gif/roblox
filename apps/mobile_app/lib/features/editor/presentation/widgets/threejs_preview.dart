import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../../config/app_config.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Unified operation states for loading overlay management.
enum ViewerOpState {
  idle,
  engineInit,
  mannequinLoad,
  clothingApply,
  accessoryAttach,
  textureSyncLive,
  textureSyncFinal,
}

/// Professional Three.js-based 3D preview widget with:
/// - Real-time texture sync from 2D canvas
/// - Environment presets (Studio, Outdoor, Sunset, Neon)
/// - Screenshot capture & share
/// - Model loading (GLB)
class ThreeJSPreview extends StatefulWidget {
  final String? modelUrl;
  final GlobalKey? canvasKey;
  final bool showControls;
  final VoidCallback? onModelReady;
  /// When true, loads a UV-mapped box mannequin that matches the Roblox
  /// classic clothing template (585×559) instead of the smooth R15 GLB.
  final bool useClassicMannequin;

  const ThreeJSPreview({
    super.key,
    this.modelUrl,
    this.canvasKey,
    this.showControls = true,
    this.onModelReady,
    this.useClassicMannequin = false,
  });

  @override
  State<ThreeJSPreview> createState() => ThreeJSPreviewState();
}

class ThreeJSPreviewState extends State<ThreeJSPreview> {
  InAppWebViewController? _webController;
  bool _isLoaded = false;
  bool _modelReady = false;
  bool _uvGuardPassed = false;
  bool _glbLoadFailed = false;
  String _currentEnv = 'studio';
  bool _isSyncing = false;

  // ── Loading state system ──
  ViewerOpState _opState = ViewerOpState.engineInit;
  DateTime? _opStartTime;
  bool _overlayVisible = true; // starts visible — hides naked flash
  Timer? _overlayShowTimer;
  Timer? _overlayHideTimer;
  int _activeOpToken = 0;

  @override
  void dispose() {
    _overlayShowTimer?.cancel();
    _overlayHideTimer?.cancel();
    super.dispose();
  }

  /// Begin an operation — returns a token for race-safe completion.
  int beginOp(ViewerOpState state) {
    final token = ++_activeOpToken;
    _opState = state;
    _opStartTime = DateTime.now();
    debugPrint('[loading] state=$state shown=pending token=$token');
    _overlayShowTimer?.cancel();
    _overlayShowTimer = Timer(const Duration(milliseconds: 120), () {
      if (_opState != ViewerOpState.idle && mounted) {
        setState(() => _overlayVisible = true);
        debugPrint('[loading] state=$state shown=true token=$token');
      }
    });
    return token;
  }

  /// End an operation — only clears if token matches (race-safe).
  void endOp(int token) {
    if (token != _activeOpToken) {
      debugPrint('[loading] end_ignored reason=stale_token expected=$_activeOpToken got=$token');
      return;
    }
    final durationMs = _opStartTime != null
        ? DateTime.now().difference(_opStartTime!).inMilliseconds : 0;
    debugPrint('[loading] state=$_opState shown=$_overlayVisible durationMs=$durationMs token=$token');
    _overlayShowTimer?.cancel();
    _opState = ViewerOpState.idle;
    if (_overlayVisible) {
      _overlayHideTimer?.cancel();
      final elapsed = _opStartTime != null
          ? DateTime.now().difference(_opStartTime!).inMilliseconds : 300;
      final remaining = (300 - elapsed).clamp(0, 300);
      _overlayHideTimer = Timer(Duration(milliseconds: remaining), () {
        if (mounted) setState(() => _overlayVisible = false);
      });
    }
  }

  /// Close whatever operation is currently active.
  void endCurrentOp() => endOp(_activeOpToken);

  String get _overlayText {
    switch (_opState) {
      case ViewerOpState.clothingApply:
        return 'Kıyafet uygulanıyor…';
      case ViewerOpState.accessoryAttach:
        return 'Aksesuar yerleştiriliyor…';
      case ViewerOpState.textureSyncLive:
      case ViewerOpState.textureSyncFinal:
        return 'Önizleme güncelleniyor…';
      case ViewerOpState.engineInit:
      case ViewerOpState.mannequinLoad:
        return 'Yükleniyor…';
      default:
        return '';
    }
  }

  /// Whether the 3D mannequin model has been fully loaded.
  bool get isModelReady => _modelReady;

  /// Whether the UV guard validation passed (GLB has proper Roblox UV mapping).
  bool get isUVGuardPassed => _uvGuardPassed;

  /// Mannequin builder JS — uses window globals exported by HTML module.
  /// Hot-reloadable because this lives in Dart, not in the HTML asset.
  static const _buildMannequinJS = """
(function() {
  var T = window.THREE;
  var scene = window._scene;
  var camera = window._camera;
  var controls = window._controls;
  if (!T || !scene) { console.error('[Mannequin] Globals not ready'); return; }

  var old = window._currentModel.get();
  if (old) { scene.remove(old); window._currentModel.set(null); }

  var mat = new T.MeshStandardMaterial({ color: 0xFFFFFF, roughness: 0.4, metalness: 0.0 });
  var darkMat = new T.MeshStandardMaterial({ color: 0xFFFFFF, roughness: 0.4, metalness: 0.0 });

  function mp(name, w, h, d, x, y, z, m) {
    var geo = new T.BoxGeometry(w, h, d);
    var mesh = new T.Mesh(geo, m || mat);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    var edges = new T.LineSegments(new T.EdgesGeometry(geo), new T.LineBasicMaterial({ color: 0xCC0000 }));
    var g = new T.Group();
    g.name = name;
    g.add(mesh); g.add(edges);
    g.position.set(x, y, z);
    return g;
  }

  var root = new T.Group();
  root.name = 'HumanoidRootPart';

  // ALL parts precisely match Roblox R15 "Block" classic proportions. Width, Height, Depth and Y stacking.
  root.add(mp('Head', 1.2, 1.2, 1.2, 0, 3.7, 0));
  var neck = new T.Group(); neck.name = 'Neck'; neck.position.set(0, 3.1, 0);
  root.add(neck);
  root.add(mp('UpperTorso', 2.0, 1.6, 1.0, 0, 2.3, 0));
  root.add(mp('LowerTorso', 2.0, 0.4, 1.0, 0, 1.3, 0));
  root.add(mp('LeftUpperArm',  1.0, 1.15, 1.0, -1.5, 2.5, 0));
  root.add(mp('LeftLowerArm',  1.0, 1.15, 1.0, -1.5, 1.35, 0));
  root.add(mp('RightUpperArm', 1.0, 1.15, 1.0,  1.5, 2.5, 0));
  root.add(mp('RightLowerArm', 1.0, 1.15, 1.0,  1.5, 1.35, 0));
  root.add(mp('LeftUpperLeg',  1.0, 1.2, 1.0, -0.5, 0.5, 0, darkMat));
  root.add(mp('LeftLowerLeg',  1.0, 1.2, 1.0, -0.5, -0.7, 0, darkMat));
  root.add(mp('LeftFoot',      1.0, 0.3, 1.0, -0.5, -1.45, 0, darkMat));
  root.add(mp('RightUpperLeg', 1.0, 1.2, 1.0,  0.5, 0.5, 0, darkMat));
  root.add(mp('RightLowerLeg', 1.0, 1.2, 1.0,  0.5, -0.7, 0, darkMat));
  root.add(mp('RightFoot',     1.0, 0.3, 1.0,  0.5, -1.45, 0, darkMat));
  // FACE perfectly scaled for 1.2 cube head
  var eM = new T.MeshBasicMaterial({ color: 0x1a1a1a });
  var lE = new T.Mesh(new T.BoxGeometry(0.15, 0.15, 0.05), eM);
  lE.position.set(-0.25, 3.85, 0.61);
  var rE = new T.Mesh(new T.BoxGeometry(0.15, 0.15, 0.05), eM);
  rE.position.set(0.25, 3.85, 0.61);
  var sM = new T.Mesh(new T.BoxGeometry(0.4, 0.1, 0.05), new T.MeshBasicMaterial({ color: 0x2a2a2a }));
  sM.position.set(0, 3.5, 0.61);
  root.add(lE, rE, sM);

  // No initial rotation — character faces front, user rotates via touch

  window._currentModel.set(root);
  var currentModel = root;

  var box = new T.Box3().setFromObject(currentModel);
  var size = box.getSize(new T.Vector3());
  console.log('[Mannequin] RAW size X=' + size.x.toFixed(2) + ' Y=' + size.y.toFixed(2) + ' Z=' + size.z.toFixed(2));
  var maxDim = Math.max(size.x, size.y, size.z);
  var sc = 3.0 / maxDim;
  currentModel.scale.setScalar(sc);
  currentModel.position.set(0, 0, 0);
  var box2 = new T.Box3().setFromObject(currentModel);
  var c2 = box2.getCenter(new T.Vector3());
  currentModel.position.x = -c2.x;
  currentModel.position.z = -c2.z;
  currentModel.position.y = -box2.min.y;
  scene.add(currentModel);

  var fb = new T.Box3().setFromObject(currentModel);
  var fs = fb.getSize(new T.Vector3());
  console.log('[Mannequin] SCALED size X=' + fs.x.toFixed(2) + ' Y=' + fs.y.toFixed(2) + ' Z=' + fs.z.toFixed(2));

  window._modelBounds.set(fb);

  camera.fov = 50;
  camera.updateProjectionMatrix();
  camera.position.set(0, 1.5, 4.5);
  controls.target.set(0, 1.3, 0);
  controls.enableDamping = true;
  controls.update();

  console.log('[Mannequin] Built from DART — hot-reloadable');
  if (window.flutter_inappwebview) {
    window.flutter_inappwebview.callHandler('onModelLoaded', true);
  }
})();
""";


  static const _environments = [
    ('studio', Icons.lightbulb_outline, 'Studio'),
    ('outdoor', Icons.wb_sunny, 'Outdoor'),
    ('sunset', Icons.wb_twilight, 'Sunset'),
    ('neon', Icons.auto_awesome, 'Neon'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Three.js WebView
            InAppWebView(
              initialFile: 'assets/threejs_viewer.html',
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
                supportZoom: false,
                allowFileAccess: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                useHybridComposition: true,
                mediaPlaybackRequiresUserGesture: false,
              ),
              onWebViewCreated: (controller) {
                _webController = controller;
                // Register handlers
                controller.addJavaScriptHandler(
                  handlerName: 'onModelLoaded',
                  callback: (args) {
                    debugPrint('[ThreeJS] Model loaded: $args');
                    setState(() => _isLoaded = true);
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'onUVGuardResult',
                  callback: (args) {
                    final status = args.isNotEmpty ? args[0].toString() : 'unknown';
                    debugPrint('[ThreeJS] UV Guard result: $status');
                    final passed = (status == 'pass');
                    setState(() => _uvGuardPassed = passed);
                    if (passed && !_modelReady) {
                      _modelReady = true;
                      // DON'T endOp here — let the editor callback
                      // decide when clothing is fully applied.
                      widget.onModelReady?.call();
                    } else if (!passed) {
                      debugPrint('[ThreeJS] UV Guard FAILED — classic clothing will be blocked');
                    }
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'onClassicTextureBlocked',
                  callback: (args) {
                    debugPrint('[ThreeJS] Classic texture BLOCKED by UV guard: $args');
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'onScreenshot',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      _handleScreenshot(args[0] as String);
                    }
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'onAccessoryAttached',
                  callback: (args) {
                    debugPrint('[ThreeJS] Accessory attached: $args');
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'onTextureSwapDone',
                  callback: (args) {
                    final mode = args.isNotEmpty ? args[0] : 'unknown';
                    final token = args.length > 1 ? (args[1] is int ? args[1] as int : int.tryParse(args[1].toString()) ?? -1) : -1;
                    debugPrint('[swap] texture_swap_done mode=$mode token=$token');
                    endOp(token);
                  },
                );
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint('[ThreeJS Console] ${consoleMessage.messageLevel}: ${consoleMessage.message}');
                // Detect model loaded signal — BUT wait for UV guard before declaring ready
                if (consoleMessage.message.contains('Model loaded') ||
                    consoleMessage.message.contains('SUCCESS')) {
                  // Model geometry is loaded; onModelReady fires when UV guard passes
                  // (handled in onUVGuardResult handler above)
                }
              },
              onLoadStop: (controller, url) async {
                setState(() => _isLoaded = true);
                // Wait for Three.js ES module to export globals to window
                for (int i = 0; i < 30; i++) {
                  final ready = await _webController!.evaluateJavascript(
                    source: "window.THREE ? 'ready' : 'waiting'",
                  );
                  if (ready == 'ready') {
                    debugPrint('[ThreeJS] Globals ready...');

                    // ─── CLASSIC CLOTHING UV-MAPPED MANNEQUIN ─────────
                    // If useClassicMannequin is true, build the box mannequin
                    // with per-face UV matching the Roblox template layout.
                    if (widget.useClassicMannequin) {
                      debugPrint('[truth] useClassicMannequin=true');
                      debugPrint('[truth] mannequinSource=classic_uv');
                      debugPrint('[truth] applyStrategy=prebaked_only');
                      debugPrint('[truth] frontBackMode=per_face_uv_baked');
                      debugPrint('[ThreeJS] Loading classic clothing mannequin (Roblox UV)...');
                      await _webController!.evaluateJavascript(
                        source: 'window.loadClassicMannequin();',
                      );
                    } else {
                      debugPrint('[truth] useClassicMannequin=false');
                      debugPrint('[truth] mannequinSource=glb');
                      debugPrint('[truth] applyStrategy=uv_rewrite');
                      debugPrint('[truth] frontBackMode=camera_verified_v11');
                    final targetUrl = widget.modelUrl ?? 'assets/roblox_r15_mannequin.glb';
                    if (targetUrl.startsWith('assets/')) {
                      try {
                        debugPrint('[ThreeJS] Loading $targetUrl via base64...');
                        final data = await rootBundle.load(targetUrl);
                        final base64String = base64Encode(data.buffer.asUint8List());
                        await _webController!.evaluateJavascript(
                          source: "window.loadModelFromBase64('$base64String');",
                        );
                      } catch (e) {
                        // ─── NO PROCEDURAL FALLBACK ───────────────────────
                        // Classic clothing requires GLB with proper UV mapping.
                        // Procedural BoxGeometry UV is incompatible.
                        debugPrint('[mannequin] glb_load_failed_no_procedural_fallback: $e');
                        setState(() => _glbLoadFailed = true);
                        // Notify Flutter handlers that model load failed
                        widget.onModelReady?.call(); // Still fire so UI isn't stuck
                      }
                    } else if (targetUrl.startsWith('http')) {
                      debugPrint('[ThreeJS] Loading remote GLB: $targetUrl');
                      await _webController!.evaluateJavascript(
                        source: "window.loadModel('$targetUrl');",
                      );
                    } else {
                      // Non-asset, non-http URL — cannot load, show error
                      debugPrint('[mannequin] glb_load_failed_no_procedural_fallback: unsupported URL: $targetUrl');
                      setState(() => _glbLoadFailed = true);
                    }
                    } // end useClassicMannequin else
                    break;
                  }
                  await Future.delayed(const Duration(milliseconds: 150));
                }
              },
            ),

            // Loading overlay — initial engine load
            if (!_isLoaded && !_overlayVisible)
              Container(
                color: const Color(0xFFF0F0F3),
                child: Center(
                  child: SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                ),
              ),

            // GLB load failure overlay
            if (_glbLoadFailed)
              Container(
                color: const Color(0xFFF0F0F3),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 36, color: Colors.red.withValues(alpha: 0.7)),
                        SizedBox(height: 10),
                        Text(
                          '3D Model Yüklenemedi',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Mannequin GLB dosyası bulunamadı.\nClassic clothing doğru UV mapping gerektirir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: AppColors.outlineVariant, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Controls overlay
            if (widget.showControls && _isLoaded) ...[
              // Environment presets (top-right)
              Positioned(
                top: 6, right: 6,
                child: Column(
                  children: _environments.map((env) {
                    final isActive = _currentEnv == env.$1;
                    return GestureDetector(
                      onTap: () => setEnvironment(env.$1),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 3),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary.withValues(alpha: 0.9)
                              : Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(env.$2, size: 14, color: Colors.white),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Screenshot button (bottom-right)
              Positioned(
                bottom: 6, right: 6,
                child: GestureDetector(
                  onTap: takeScreenshot,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ),

              // Sync indicator (legacy)
              if (_isSyncing && !_overlayVisible)
                Positioned(
                  bottom: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white)),
                        SizedBox(width: 4),
                        Text('Syncing...', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],

            // ── Unified loading overlay (frosted glass) ──
            if (_overlayVisible)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: AnimatedOpacity(
                      opacity: _overlayVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.25),
                        child: const Center(
                          child: _StaggeredBlocksLoader(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Public API ─────────────────────────────────────────────────────

  /// Update the 3D model's texture from a canvas RepaintBoundary.
  Future<void> syncTextureFromCanvas(GlobalKey canvasKey) async {
    if (_webController == null) return;
    setState(() => _isSyncing = true);

    try {
      final boundary = canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final base64 = base64Encode(byteData.buffer.asUint8List());
      await _webController!.evaluateJavascript(source: "window.updateTexture('$base64')");
    } catch (e) {
      debugPrint('Texture sync error: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Load a GLB model from Flutter asset bundle via base64.
  /// This bypasses the fetch() file:// limitation in Android WebView.
  Future<void> loadModelFromAsset(String assetPath) async {
    if (_webController == null) return;
    try {
      debugPrint('[ThreeJS] Loading asset: $assetPath');
      final data = await rootBundle.load(assetPath);
      final base64 = base64Encode(data.buffer.asUint8List());
      debugPrint('[ThreeJS] Asset loaded, base64 length: ${base64.length}');
      await _webController!.evaluateJavascript(
        source: "window.loadModelFromBase64('$base64')",
      );
    } catch (e) {
      debugPrint('[ThreeJS] Asset load error: $e');
    }
  }

  /// Load a GLB model by URL (for CDN/network URLs only).
  Future<void> loadModel(String url) async {
    if (_webController == null) return;
    await _webController!.evaluateJavascript(source: "window.loadModel('$url')");
  }

  /// Send a pre-masked base64 PNG texture directly to the 3D engine.
  /// DEPRECATED: For classic clothing, use [applyClassicTexture] instead.
  Future<void> updateTextureFromBase64(String base64) async {
    if (_webController == null) return;
    await _webController!.evaluateJavascript(source: "window.updateTexture('$base64')");
  }

  /// Apply a classic clothing texture using the canonical pipeline.
  /// [mode] must be one of: 'shirt', 'pants', 'set', 'tshirt'.
  /// [opToken] enables race-safe loading state management.
  /// Both Editor and Preview MUST use this method for deterministic results.
  Future<void> applyClassicTexture(String base64, String mode, {int? opToken}) async {
    if (_webController == null) return;
    final token = opToken ?? 0;
    await _webController!.evaluateJavascript(
      source: "window.applyClassicTexture('$base64', '$mode', $token)",
    );
  }

  /// Attach an accessory from Flutter asset bundle OR network URL via base64.
  /// [sourceKeyFromFlutter] is passed as an independent telemetry key so JS
  /// can verify that the Dart-side key matches the JS-side slot key.
  Future<void> attachAccessory(String assetPath, String slotId, {String? sourceKeyFromFlutter}) async {
    if (_webController == null) return;
    final srcKey = sourceKeyFromFlutter ?? slotId;
    try {
      debugPrint('[ThreeJS] Loading accessory: $assetPath, slot: $slotId, sourceKey: $srcKey');
      
      Uint8List bytes;
      if (assetPath.startsWith('http://') || assetPath.startsWith('https://')) {
        // Remote URL — download via HTTP
        final response = await http.get(Uri.parse(assetPath));
        if (response.statusCode != 200) {
          debugPrint('[ThreeJS] HTTP download failed: ${response.statusCode}');
          return;
        }
        bytes = response.bodyBytes;
      } else {
        // Local asset — load from bundle
        final data = await rootBundle.load(assetPath);
        bytes = data.buffer.asUint8List();
      }
      
      final base64 = base64Encode(bytes);
      debugPrint('[ThreeJS] Accessory loaded, base64 length: ${base64.length}');
      await _webController!.evaluateJavascript(
        source: "window.attachAccessoryFromBase64('$base64', '$slotId', '$srcKey')",
      );
    } catch (e) {
      debugPrint('[ThreeJS] Accessory load error: $e');
    }
  }

  /// Update the transform of an attached accessory.
  Future<void> updateAccessoryTransform(String slotId, {double x=0, double y=0, double z=0, double rx=0, double ry=0, double rz=0, double s=1}) async {
    if (_webController == null) return;
    await _webController!.evaluateJavascript(
        source: "window.updateAccessoryTransform('$slotId', $x, $y, $z, $rx, $ry, $rz, $s)"
    );
  }

  /// Remove an accessory from a slot.
  Future<void> removeAccessory(String slotId) async {
    if (_webController == null) return;
    await _webController!.evaluateJavascript(source: "window.removeAccessory('$slotId')");
  }

  /// Set environment preset.
  Future<void> setEnvironment(String envName) async {
    if (_webController == null) return;
    setState(() => _currentEnv = envName);
    await _webController!.evaluateJavascript(source: "window.setEnvironment('$envName')");
  }

  /// Take a screenshot of the 3D view.
  Future<void> takeScreenshot() async {
    if (_webController == null) return;
    await _webController!.evaluateJavascript(source: "window.takeScreenshot()");
  }

  /// Apply a solid color to specific body regions (upper/lower/head/all).
  Future<void> applyRegionColor(String region, Color color) async {
    if (_webController == null) return;
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    await _webController!.evaluateJavascript(
      source: "window.applyRegionColor('$region', '$hex')",
    );
  }

  Future<void> resetCamera() async {
    if (_webController == null) return;
    await _webController!.evaluateJavascript(source: 'window.resetCamera()');
  }

  /// Apply color to all clothing regions at once.
  Future<void> applyClothingColor(Color color) async {
    if (_webController == null) return;
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    await _webController!.evaluateJavascript(
      source: "window.applyClothingColor('$hex')",
    );
  }

  /// Set camera to front/back view (0° = front, 180° = back).
  Future<void> setViewAngle(int angleDeg) async {
    if (_webController == null) return;
    await _webController!.evaluateJavascript(
      source: "window.setViewAngle($angleDeg)",
    );
  }

  /// V9 FORENSIC PROBE — run after model load to verify front/back mapping.
  /// Applies a labeled texture (FRONT=green, BACK=red, R=blue, L=yellow)
  /// and logs camera + attachment world positions.
  /// PASS condition: green FRONT visible when camera is at angle=0 (+Z side).
  /// [stepLabel] is appended to log output for multi-step testing.
  Future<void> runFrontBackProbe({String stepLabel = 'default'}) async {
    if (_webController == null) return;
    debugPrint('[probe-dart] Running V9 front/back probe step=$stepLabel');
    await _webController!.evaluateJavascript(
      source: "window.runFrontBackProbe(); console.log('[probe] step=$stepLabel done');",
    );
  }

  /// V9 PROBE WITH ASSERTION — automated front/back verification.
  /// Applies probe texture, then reads center pixel at angle=0 and angle=180.
  /// Logs [uv-assert] pass or FAIL. Takes ~2s to complete.
  Future<void> runProbeWithAssert() async {
    if (_webController == null) return;
    debugPrint('[probe-dart] Running V9 probe with assertion');
    await _webController!.evaluateJavascript(
      source: "window.runProbeWithAssert();",
    );
  }

  // ─── Screenshot handling ────────────────────────────────────────────

  Future<void> _handleScreenshot(String dataUrl) async {
    try {
      final base64Data = dataUrl.split(',').last;
      final bytes = base64Decode(base64Data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/3d_screenshot_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        // Show share dialog
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Created with ${AppConfig.appNameShort}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.editorScreenshotFailed(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  3D Rotating Cubes Loader — brand-colored with perspective
// ═══════════════════════════════════════════════════════════════════
class _StaggeredBlocksLoader extends StatefulWidget {
  const _StaggeredBlocksLoader();

  @override
  State<_StaggeredBlocksLoader> createState() => _StaggeredBlocksLoaderState();
}

class _StaggeredBlocksLoaderState extends State<_StaggeredBlocksLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Brand palette
  static const _colors = [
    Color(0xFFFF793A), // primaryContainer
    Color(0xFFFF5722), // deep orange
    Color(0xFF9F3B00), // primary
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(3, (i) {
              // Staggered phase per cube
              final phase = i / 3.0;
              final t = ((_ctrl.value + phase) % 1.0);

              // Y-axis rotation (full 360°)
              final rotY = t * 2.0 * math.pi;
              // X-axis gentle tilt (subtle wobble)
              final rotX = math.sin(t * 2.0 * math.pi) * 0.3;
              // Scale pulse
              final pulse = math.sin(t * math.pi);
              final scale = 0.7 + 0.3 * pulse;
              // Vertical float
              final yFloat = math.sin(t * 2.0 * math.pi) * 6.0;
              // Opacity
              final opacity = (0.5 + 0.5 * pulse).clamp(0.0, 1.0);

              final color = _colors[i];

              // 3D perspective matrix
              final m = Matrix4.identity()
                ..setEntry(3, 2, 0.003)
                ..rotateY(rotY)
                ..rotateX(rotX)
                ..scale(scale, scale, 1.0);

              return Positioned(
                left: 12.0 + i * 16.0,
                top: 24.0 + yFloat,
                child: Opacity(
                  opacity: opacity,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: m,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5 * opacity),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

