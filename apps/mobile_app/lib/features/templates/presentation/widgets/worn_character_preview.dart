import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Catalog thumbnail: each card maps its own Shirt/Pants UV onto a blocky
/// mannequin. A shared 3D still renderer was not used here — one WebView
/// screenshot queue painted the same frame onto every card.
class WornCharacterPreview extends StatefulWidget {
  const WornCharacterPreview({
    super.key,
    this.shirtUrl,
    this.pantsUrl,
    this.atlasUrl,
    this.templateType,
    this.backgroundColor = const Color(0xFFF0F0F3),
  });

  factory WornCharacterPreview.fromTemplateRow(
    Map<String, dynamic> row, {
    Key? key,
    Color backgroundColor = const Color(0xFFF0F0F3),
  }) {
    return WornCharacterPreview(
      key: key,
      shirtUrl: row['shirt_texture_url'] as String?,
      pantsUrl: row['pants_texture_url'] as String?,
      templateType: row['template_type'] as String?,
      backgroundColor: backgroundColor,
    );
  }

  /// Library draft/export: prefer catalog shirt/pants URLs (same as Home).
  /// Falls back to the saved UV thumbnail when those URLs are missing.
  factory WornCharacterPreview.fromLibraryRow(
    Map<String, dynamic> row, {
    Key? key,
    Color backgroundColor = const Color(0xFFF0F0F3),
  }) {
    final shirt = httpUrl(row['shirt_texture_url']);
    final pants = httpUrl(row['pants_texture_url']);
    final hasWornUrls = shirt != null || pants != null;
    return WornCharacterPreview(
      key: key,
      shirtUrl: shirt,
      pantsUrl: pants,
      atlasUrl: hasWornUrls ? null : row['thumbnail_url'] as String?,
      templateType: row['template_type'] as String?,
      backgroundColor: backgroundColor,
    );
  }

  static String? httpUrl(dynamic value) {
    final url = value as String?;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return null;
  }

  final String? shirtUrl;
  final String? pantsUrl;
  final String? atlasUrl;
  final String? templateType;
  final Color backgroundColor;

  @override
  State<WornCharacterPreview> createState() => _WornCharacterPreviewState();
}

class _WornCharacterPreviewState extends State<WornCharacterPreview> {
  ui.Image? _shirt;
  ui.Image? _pants;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAtlases();
  }

  @override
  void didUpdateWidget(covariant WornCharacterPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shirtUrl != widget.shirtUrl ||
        oldWidget.pantsUrl != widget.pantsUrl ||
        oldWidget.atlasUrl != widget.atlasUrl ||
        oldWidget.templateType != widget.templateType) {
      _loadAtlases();
    }
  }

  Future<void> _loadAtlases() async {
    setState(() => _loading = true);
    ui.Image? shirt;
    ui.Image? pants;
    if (widget.atlasUrl != null && widget.atlasUrl!.isNotEmpty) {
      final atlas = await _AtlasCache.load(widget.atlasUrl);
      if (atlas != null) {
        final split = await _splitLibraryAtlas(atlas, widget.templateType);
        shirt = split.$1;
        pants = split.$2;
      }
    } else {
      shirt = await _AtlasCache.load(widget.shirtUrl);
      pants = await _AtlasCache.load(widget.pantsUrl);
    }
    if (!mounted) return;
    setState(() {
      _shirt = shirt;
      _pants = pants;
      _loading = false;
    });
  }

  static Future<(ui.Image?, ui.Image?)> _splitLibraryAtlas(
    ui.Image atlas,
    String? type,
  ) async {
    if (atlas.height >= 1000) {
      final scale = atlas.width / 585.0;
      final band = (559 * scale).round().clamp(1, atlas.height);
      final gap = (10 * scale).round();
      final shirt = await _crop(atlas, 0, 0, atlas.width, band);
      final pantsTop = (band + gap).clamp(0, atlas.height - 1);
      final pantsH = band.clamp(1, atlas.height - pantsTop);
      final pants = await _crop(atlas, 0, pantsTop, atlas.width, pantsH);
      return (shirt, pants);
    }
    if (type == 'classic_pants') return (null, atlas);
    return (atlas, null);
  }

  static Future<ui.Image> _crop(ui.Image src, int x, int y, int w, int h) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final dest = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
      dest,
      Paint()..filterQuality = FilterQuality.medium,
    );
    return recorder.endRecording().toImage(w, h);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: _loading && _shirt == null && _pants == null
          ? const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0x66FF793A),
                ),
              ),
            )
          : CustomPaint(
              painter: _BlockyMannequinPainter(
                shirt: _shirt,
                pants: _pants,
                templateType: widget.templateType,
              ),
              child: const SizedBox.expand(),
            ),
    );
  }
}

class _AtlasCache {
  static final Map<String, ui.Image> _ready = {};
  static final Map<String, Future<ui.Image?>> _inflight = {};

  static Future<ui.Image?> load(String? url) {
    if (url == null || url.isEmpty) return Future.value(null);
    final cached = _ready[url];
    if (cached != null) return Future.value(cached);
    return _inflight.putIfAbsent(url, () async {
      try {
        final image = await _decode(url);
        _ready[url] = image;
        return image;
      } catch (_) {
        return null;
      } finally {
        _inflight.remove(url);
      }
    });
  }

  static Future<ui.Image> _decode(String url) {
    final completer = Completer<ui.Image>();
    final stream = CachedNetworkImageProvider(url).resolve(
      const ImageConfiguration(),
    );
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

class _Uv {
  static const w = 585.0;
  static const h = 559.0;

  static const torsoFront = Rect.fromLTWH(231, 73, 130, 130);
  static const torsoRight = Rect.fromLTWH(164, 73, 66, 130);

  static const rightArmFront = Rect.fromLTWH(217, 349, 66, 114);
  static const rightArmRight = Rect.fromLTWH(151, 349, 66, 114);
  static const leftArmFront = Rect.fromLTWH(308, 349, 66, 114);
  static const leftArmLeft = Rect.fromLTWH(506, 349, 66, 114);

  static const rightLegFront = Rect.fromLTWH(217, 349, 66, 114);
  static const rightLegRight = Rect.fromLTWH(151, 349, 66, 114);
  static const leftLegFront = Rect.fromLTWH(308, 349, 66, 114);
  static const leftLegLeft = Rect.fromLTWH(506, 349, 66, 114);
}

class _BlockyMannequinPainter extends CustomPainter {
  _BlockyMannequinPainter({
    required this.shirt,
    required this.pants,
    required this.templateType,
  });

  final ui.Image? shirt;
  final ui.Image? pants;
  final String? templateType;

  static const _skin = Color(0xFFD4D4D4);

  bool get _shirtOnTorso =>
      shirt != null && templateType != 'classic_pants';
  bool get _shirtOnArms =>
      shirt != null &&
      templateType != 'classic_pants' &&
      templateType != 'classic_tshirt';
  bool get _pantsOnLegs =>
      pants != null && templateType != 'classic_tshirt';

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 5.15;
    final cx = size.width * 0.50;
    final top = size.height * 0.08;
    final side = unit * 0.18;

    final head = Rect.fromCenter(
      center: Offset(cx, top + unit * 0.52),
      width: unit * 0.92,
      height: unit * 0.98,
    );
    final torso = Rect.fromLTWH(
      cx - unit * 1.02,
      head.bottom + unit * 0.02,
      unit * 2.04,
      unit * 1.72,
    );
    final rightArm = Rect.fromLTWH(
      torso.left - unit * 0.78,
      torso.top + unit * 0.06,
      unit * 0.74,
      unit * 1.58,
    );
    final leftArm = Rect.fromLTWH(
      torso.right,
      torso.top + unit * 0.06,
      unit * 0.74,
      unit * 1.58,
    );
    final rightLeg = Rect.fromLTWH(
      torso.left + unit * 0.08,
      torso.bottom,
      unit * 0.90,
      unit * 1.62,
    );
    final leftLeg = Rect.fromLTWH(
      torso.right - unit * 0.98,
      torso.bottom,
      unit * 0.90,
      unit * 1.62,
    );

    _drawShadow(canvas, Offset(cx, leftLeg.bottom + unit * 0.08), unit * 1.7);

    _drawBlock(
      canvas: canvas,
      front: rightArm,
      side: side,
      atlas: _shirtOnArms ? shirt : null,
      frontUv: _Uv.rightArmFront,
      sideUv: _Uv.rightArmRight,
    );
    _drawBlock(
      canvas: canvas,
      front: rightLeg,
      side: side,
      atlas: _pantsOnLegs ? pants : null,
      frontUv: _Uv.rightLegFront,
      sideUv: _Uv.rightLegRight,
    );
    _drawBlock(
      canvas: canvas,
      front: leftLeg,
      side: side,
      atlas: _pantsOnLegs ? pants : null,
      frontUv: _Uv.leftLegFront,
      sideUv: _Uv.leftLegLeft,
    );
    _drawBlock(
      canvas: canvas,
      front: torso,
      side: side,
      atlas: _shirtOnTorso ? shirt : null,
      frontUv: _Uv.torsoFront,
      sideUv: _Uv.torsoRight,
    );
    _drawBlock(
      canvas: canvas,
      front: leftArm,
      side: side,
      atlas: _shirtOnArms ? shirt : null,
      frontUv: _Uv.leftArmFront,
      sideUv: _Uv.leftArmLeft,
    );
    _drawHead(canvas, head);
  }

  void _drawShadow(Canvas canvas, Offset center, double width) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: width * 0.18),
      Paint()..color = const Color(0x22000000),
    );
  }

  void _drawHead(Canvas canvas, Rect front) {
    final frontR = RRect.fromRectAndRadius(
      front,
      Radius.circular(front.width * 0.22),
    );
    canvas.drawRRect(frontR, Paint()..color = _skin);
    canvas.drawRRect(
      frontR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x33FFFFFF), Color(0x14000000)],
        ).createShader(front),
    );
  }

  void _drawBlock({
    required Canvas canvas,
    required Rect front,
    required double side,
    required ui.Image? atlas,
    required Rect frontUv,
    required Rect sideUv,
  }) {
    final sidePath = Path()
      ..moveTo(front.right, front.top)
      ..lineTo(front.right + side, front.top - side * 0.38)
      ..lineTo(front.right + side, front.bottom - side * 0.38)
      ..lineTo(front.right, front.bottom)
      ..close();

    if (atlas != null) {
      canvas.save();
      canvas.clipPath(sidePath);
      _blit(canvas, atlas, sideUv, sidePath.getBounds());
      canvas.restore();
      canvas.drawPath(sidePath, Paint()..color = const Color(0x33000000));
    } else {
      canvas.drawPath(sidePath, Paint()..color = const Color(0xFFBDBDBD));
    }

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(front, Radius.circular(front.width * 0.04)),
    );
    if (atlas != null) {
      _blit(canvas, atlas, frontUv, front);
    } else {
      canvas.drawRect(front, Paint()..color = _skin);
    }
    canvas.drawRect(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x28FFFFFF), Color(0x00000000), Color(0x22000000)],
          stops: [0, 0.45, 1],
        ).createShader(front),
    );
    canvas.restore();
  }

  void _blit(Canvas canvas, ui.Image image, Rect uv, Rect dest) {
    final sx = image.width / _Uv.w;
    final sy = image.height / _Uv.h;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(uv.left * sx, uv.top * sy, uv.width * sx, uv.height * sy),
      dest,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _BlockyMannequinPainter old) {
    return old.shirt != shirt ||
        old.pants != pants ||
        old.templateType != templateType;
  }
}
