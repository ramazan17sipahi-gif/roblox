import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import '../../../config/app_config.dart';

/// Downloads a catalog Shirt or Pants PNG, stamps a translucent brand
/// mark in the bottom-left, and saves it to the photo library.
class SkinDownloadService {
  static Future<void> saveWatermarkedTexture({
    required String sourcePath,
    required String fileName,
  }) async {
    final raw = await _loadBytes(sourcePath);
    final stamped = await _applyLogoWatermark(raw);
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw Exception('Photo library permission denied');
      }
    }
    await Gal.putImageBytes(stamped, name: fileName);
  }

  static Future<Uint8List> _loadBytes(String path) async {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final response = await http.get(Uri.parse(path));
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }
      return response.bodyBytes;
    }
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  static Future<Uint8List> _applyLogoWatermark(Uint8List sourcePng) async {
    final src = await _decodePng(sourcePng);
    final logoData = await rootBundle.load(AppConfig.logoAsset);
    final logoWidth = (src.width * 0.20).round().clamp(56, 120);
    final logo = await _decodePng(
      logoData.buffer.asUint8List(),
      targetWidth: logoWidth,
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(src, Offset.zero, ui.Paint());

    final pad = src.width * 0.04;
    final dest = ui.Offset(pad, src.height - logo.height - pad);
    canvas.saveLayer(
      null,
      ui.Paint()..color = const ui.Color.fromRGBO(255, 255, 255, 0.38),
    );
    canvas.drawImage(logo, dest, ui.Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    final out = await picture.toImage(src.width, src.height);
    final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
    src.dispose();
    logo.dispose();
    out.dispose();
    picture.dispose();
    if (bytes == null) {
      throw Exception('Failed to encode watermarked image');
    }
    return bytes.buffer.asUint8List();
  }

  static Future<ui.Image> _decodePng(Uint8List bytes, {int? targetWidth}) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static String fileNameFor({
    required String title,
    required bool shirt,
  }) {
    final slug = title
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final base = slug.isEmpty ? 'skin' : slug;
    return '${base}_${shirt ? 'Shirt' : 'Pants'}.png';
  }
}
