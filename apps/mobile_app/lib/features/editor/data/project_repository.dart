import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for auto-saving and loading editor projects.
/// Stores project data (JSON + canvas PNG) in Supabase Storage
/// with revision history support.
class ProjectRepository {
  static final _supabase = Supabase.instance.client;
  static const _bucket = 'projects';
  static const _table = 'user_projects';

  /// Save a project (auto-save or manual).
  static Future<String?> saveProject({
    required String projectId,
    required String name,
    required String templateType,
    required Map<String, dynamic> projectData,
    Uint8List? thumbnailPng,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final jsonStr = jsonEncode(projectData);
      final now = DateTime.now().toIso8601String();

      // Upload project JSON to storage
      final jsonPath = '$userId/$projectId/project.json';
      await _supabase.storage.from(_bucket).uploadBinary(
        jsonPath,
        Uint8List.fromList(utf8.encode(jsonStr)),
        fileOptions: const FileOptions(upsert: true, contentType: 'application/json'),
      );

      // Upload thumbnail if provided (store storage path — bucket is private).
      String? thumbnailPath;
      if (thumbnailPng != null) {
        thumbnailPath = '$userId/$projectId/thumbnail.png';
        await _supabase.storage.from(_bucket).uploadBinary(
          thumbnailPath,
          thumbnailPng,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/png'),
        );
      }

      final existing = await _supabase
          .from(_table)
          .select('id')
          .eq('id', projectId)
          .maybeSingle();

      final row = <String, dynamic>{
        'id': projectId,
        'user_id': userId,
        'name': name,
        'template_type': templateType,
        'updated_at': now,
        'version': await _getNextVersion(projectId),
      };
      if (thumbnailPath != null) {
        row['thumbnail_url'] = thumbnailPath;
      }
      final shirtUrl = projectData['shirt_asset_path'] as String?;
      final pantsUrl = projectData['pants_asset_path'] as String?;
      if (shirtUrl != null && shirtUrl.isNotEmpty) {
        row['shirt_texture_url'] = shirtUrl;
      }
      if (pantsUrl != null && pantsUrl.isNotEmpty) {
        row['pants_texture_url'] = pantsUrl;
      }
      if (existing == null) {
        row['visibility'] = 'draft';
      }

      try {
        await _supabase.from(_table).upsert(row);
      } catch (e) {
        debugPrint('Save project worn-url columns skipped: $e');
        row.remove('shirt_texture_url');
        row.remove('pants_texture_url');
        await _supabase.from(_table).upsert(row);
      }

      // Save revision
      await _saveRevision(projectId, userId, jsonStr, thumbnailPath);

      return projectId;
    } catch (e) {
      debugPrint('Save project error: $e');
      return null;
    }
  }

  /// Load a project by ID.
  static Future<Map<String, dynamic>?> loadProject(String projectId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final jsonPath = '$userId/$projectId/project.json';
      final bytes = await _supabase.storage.from(_bucket).download(jsonPath);
      final jsonStr = utf8.decode(bytes);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Load project error: $e');
      return null;
    }
  }

  /// List all projects for current user.
  static Future<List<Map<String, dynamic>>> listProjects() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(response);
      for (final row in list) {
        row['thumbnail_url'] = await signedThumbnailUrl(row['thumbnail_url'] as String?);
      }
      await _hydrateWornUrls(list);
      return list;
    } catch (e) {
      debugPrint('List projects error: $e');
      return [];
    }
  }

  /// Existing drafts may only have shirt/pants URLs inside project.json.
  static Future<void> _hydrateWornUrls(List<Map<String, dynamic>> list) async {
    final missing = list.where((row) {
      final shirt = row['shirt_texture_url'] as String?;
      final pants = row['pants_texture_url'] as String?;
      return (shirt == null || shirt.isEmpty) && (pants == null || pants.isEmpty);
    }).toList();
    if (missing.isEmpty) return;

    const batchSize = 4;
    for (var i = 0; i < missing.length; i += batchSize) {
      final chunk = missing.skip(i).take(batchSize);
      await Future.wait(chunk.map((row) async {
        final id = row['id'] as String?;
        if (id == null) return;
        final data = await loadProject(id);
        if (data == null) return;
        final shirt = data['shirt_asset_path'] as String?;
        final pants = data['pants_asset_path'] as String?;
        if (shirt != null && shirt.isNotEmpty) {
          row['shirt_texture_url'] = shirt;
        }
        if (pants != null && pants.isNotEmpty) {
          row['pants_texture_url'] = pants;
        }
      }));
    }
  }

  /// Marks a project as exported for the Library Exports tab.
  static Future<bool> markExported(String projectId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      await _supabase
          .from(_table)
          .update({
            'exported_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', projectId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('Mark exported error: $e');
      return false;
    }
  }

  /// Signed URL for a private `projects` thumbnail path or legacy public URL.
  static Future<String?> signedThumbnailUrl(String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    var path = stored;
    const publicMarker = '/object/public/projects/';
    const signMarker = '/object/sign/projects/';
    final publicIdx = stored.indexOf(publicMarker);
    final signIdx = stored.indexOf(signMarker);
    if (publicIdx >= 0) {
      path = stored.substring(publicIdx + publicMarker.length).split('?').first;
    } else if (signIdx >= 0) {
      path = stored.substring(signIdx + signMarker.length).split('?').first;
    } else if (stored.startsWith('http://') || stored.startsWith('https://')) {
      return stored;
    }
    try {
      return await _supabase.storage.from(_bucket).createSignedUrl(path, 60 * 60 * 24 * 7);
    } catch (e) {
      debugPrint('Sign thumbnail error: $e');
      return stored;
    }
  }

  /// Updates project visibility (private / public / draft).
  static Future<bool> setVisibility(String projectId, String visibility) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from(_table)
          .update({'visibility': visibility, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', projectId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('Set visibility error: $e');
      return false;
    }
  }

  /// Delete a project.
  static Future<bool> deleteProject(String projectId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Delete storage files
      await _supabase.storage.from(_bucket).remove([
        '$userId/$projectId/project.json',
        '$userId/$projectId/thumbnail.png',
      ]);

      // Delete metadata
      await _supabase.from(_table).delete().eq('id', projectId);

      // Delete revisions
      await _supabase.from('project_revisions').delete().eq('project_id', projectId);

      return true;
    } catch (e) {
      debugPrint('Delete project error: $e');
      return false;
    }
  }

  // ─── Revision History ──────────────────────────────────────────────

  /// Get revision history for a project.
  static Future<List<Map<String, dynamic>>> getRevisions(String projectId) async {
    try {
      final response = await _supabase
          .from('project_revisions')
          .select()
          .eq('project_id', projectId)
          .order('version', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Get revisions error: $e');
      return [];
    }
  }

  /// Restore a specific revision.
  static Future<Map<String, dynamic>?> restoreRevision(String projectId, int version) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final revisionPath = '$userId/$projectId/revisions/v$version.json';
      final bytes = await _supabase.storage.from(_bucket).download(revisionPath);
      final jsonStr = utf8.decode(bytes);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Overwrite current project with revision
      await saveProject(
        projectId: projectId,
        name: data['name'] as String? ?? 'Restored Project',
        templateType: data['template_type'] as String? ?? 'unknown',
        projectData: data,
      );

      return data;
    } catch (e) {
      debugPrint('Restore revision error: $e');
      return null;
    }
  }

  // ─── Internal ─────────────────────────────────────────────────────

  static Future<int> _getNextVersion(String projectId) async {
    try {
      final response = await _supabase
          .from('project_revisions')
          .select('version')
          .eq('project_id', projectId)
          .order('version', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        return (response[0]['version'] as int) + 1;
      }
    } catch (e) { debugPrint('[project_repository] silent catch: $e'); }
    return 1;
  }

  static Future<void> _saveRevision(
    String projectId,
    String userId,
    String jsonStr,
    String? thumbnailUrl,
  ) async {
    try {
      final version = await _getNextVersion(projectId);

      // Upload revision JSON
      final revisionPath = '$userId/$projectId/revisions/v$version.json';
      await _supabase.storage.from(_bucket).uploadBinary(
        revisionPath,
        Uint8List.fromList(utf8.encode(jsonStr)),
        fileOptions: const FileOptions(contentType: 'application/json'),
      );

      // Record revision metadata
      await _supabase.from('project_revisions').insert({
        'project_id': projectId,
        'version': version,
        'thumbnail_url': thumbnailUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Save revision error: $e');
    }
  }
}
