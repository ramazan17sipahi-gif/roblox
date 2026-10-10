import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of picking and optionally uploading a reference image.
class ReferenceImagePickResult {
  final Uint8List bytes;
  const ReferenceImagePickResult(this.bytes);
}

/// Uploads user reference images to Supabase Storage (`reference-images` bucket).
class ReferenceImageUploadService {
  static final _client = Supabase.instance.client;
  static const _bucket = 'reference-images';

  /// Opens gallery/file picker, reads bytes, uploads to storage.
  /// Returns image bytes for immediate canvas use.
  static Future<ReferenceImagePickResult?> pickAndUpload() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) return null;

      final ext = _extension(file.name);
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _mime(ext),
              upsert: false,
            ),
          );

      return ReferenceImagePickResult(bytes);
    } catch (e) {
      debugPrint('[ReferenceImageUploadService] $e');
      return null;
    }
  }

  static String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1) return 'png';
    return name.substring(dot + 1).toLowerCase();
  }

  static String _mime(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/png';
    }
  }
}
