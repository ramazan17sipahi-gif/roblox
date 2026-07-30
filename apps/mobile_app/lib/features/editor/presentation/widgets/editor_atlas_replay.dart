import 'package:flutter/material.dart';

import 'drawing_canvas.dart';

/// Replays editor strokes and canvas elements onto an atlas [Canvas].
class EditorAtlasReplay {
  EditorAtlasReplay._();

  static void replayStroke(
    Canvas canvas,
    DrawStroke stroke, {
    required Size atlasSize,
    required double sx,
    required double sy,
  }) {
    final normWidth = stroke.width * (sx + sy) / 2;

    if (stroke.gradientType != GradientFillType.none) {
      Offset scG(Offset p) => Offset(p.dx * sx, p.dy * sy);
      final rect = (stroke.shapeStart != null && stroke.shapeEnd != null)
          ? Rect.fromPoints(scG(stroke.shapeStart!), scG(stroke.shapeEnd!))
          : Rect.fromLTWH(0, 0, atlasSize.width, atlasSize.height);
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
      } else {
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
      return;
    }

    Offset sc(Offset p) => Offset(p.dx * sx, p.dy * sy);

    if (stroke.shapeType != ShapeType.none &&
        stroke.shapeStart != null &&
        stroke.shapeEnd != null) {
      final paint = Paint()
        ..color = stroke.color.withValues(alpha: stroke.opacity)
        ..strokeWidth = normWidth
        ..blendMode = stroke.blendMode
        ..style = stroke.shapeFilled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final normStart = sc(stroke.shapeStart!);
      final normEnd = sc(stroke.shapeEnd!);
      final rect = Rect.fromPoints(normStart, normEnd);
      switch (stroke.shapeType) {
        case ShapeType.rectangle:
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
          break;
        case ShapeType.circle:
          canvas.drawOval(rect, paint);
          break;
        case ShapeType.triangle:
          canvas.drawPath(
            Path()
              ..moveTo(rect.center.dx, rect.top)
              ..lineTo(rect.right, rect.bottom)
              ..lineTo(rect.left, rect.bottom)
              ..close(),
            paint,
          );
          break;
        case ShapeType.line:
          canvas.drawLine(normStart, normEnd, paint..style = PaintingStyle.stroke);
          break;
        default:
          break;
      }
      return;
    }

    if (stroke.points.isEmpty) return;
    final paint = Paint()
      ..color = stroke.color.withValues(alpha: stroke.opacity)
      ..strokeWidth = normWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = stroke.isEraser ? BlendMode.clear : stroke.blendMode;

    if (stroke.points.length == 1) {
      canvas.drawCircle(
        sc(stroke.points.first),
        normWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final pts = stroke.points.map(sc).toList();
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      if (i < pts.length - 1) {
        final mid = Offset(
          (pts[i].dx + pts[i + 1].dx) / 2,
          (pts[i].dy + pts[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      } else {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  static void replayElement(
    Canvas canvas,
    CanvasElement element, {
    required double sx,
    required double sy,
    double yOffset = 0,
  }) {
    final normX = element.position.dx * sx;
    final normY = (element.position.dy - yOffset) * sy;
    final scaleX = element.scale * sx;
    final scaleY = element.scale * sy;

    final imgW = element.contentWidth;
    final imgH = element.contentHeight;
    final pivotX = imgW / 2;
    final pivotY = imgH / 2;

    canvas.save();
    canvas.translate(normX, normY);

    if (element.rotation != 0) {
      canvas.translate(pivotX * scaleX, pivotY * scaleY);
      canvas.rotate(element.rotation);
      canvas.translate(-pivotX * scaleX, -pivotY * scaleY);
    }

    canvas.scale(
      element.flipH ? -scaleX : scaleX,
      element.flipV ? -scaleY : scaleY,
    );
    if (element.flipH) canvas.translate(-imgW, 0);
    if (element.flipV) canvas.translate(0, -imgH);

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
  }
}
