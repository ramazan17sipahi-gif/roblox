import 'package:flutter/material.dart';
import '../../editor/data/editor_route_params.dart';

/// Data contract for the my-design-preview route.
///
/// Passed as typed `extra` to `/my-design-preview`.
class MyDesignPreviewParams {
  /// Job ID — used as unique identifier.
  final String jobId;

  /// Display title (prompt or fallback).
  final String title;

  /// Best available 3D model URL (GLB).
  final String? modelUrl;

  /// Preview thumbnail URL (2D render).
  final String? thumbnailUrl;

  /// Job status for badge display.
  final String status;

  /// Job type for mode resolution.
  final String jobType;

  /// Job creation timestamp.
  final DateTime? createdAt;

  const MyDesignPreviewParams({
    required this.jobId,
    required this.title,
    this.modelUrl,
    this.thumbnailUrl,
    this.status = 'completed',
    this.jobType = '3d_generation',
    this.createdAt,
  });

  /// Deterministic editor mode:
  /// - All job types → EditorMode.classicClothingBlankStart
  EditorMode get editorMode {
    return EditorMode.classicClothingBlankStart;
  }

  /// Build typed [EditorRouteParams] from this preview.
  EditorRouteParams toEditorParams() {
    return EditorRouteParams(
      mode: editorMode,
    );
  }

  /// Whether this design has a loadable 3D model.
  bool get hasModel => modelUrl != null && modelUrl!.isNotEmpty;

  /// Whether this design has a 2D thumbnail preview.
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
}
