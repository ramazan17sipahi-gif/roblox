import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../editor/data/editor_route_params.dart';
import '../../editor/data/project_id.dart';
import '../../editor/data/project_repository.dart';

/// Community actions: publish, like, save, remix.
class CommunityRepository {
  static final _supabase = Supabase.instance.client;

  static String categoryFromTemplate(String? templateType) {
    switch (templateType) {
      case 'classic_pants':
      case 'blankPants':
        return 'pants';
      case 'classic_tshirt':
      case 'blankTShirt':
        return 'tshirt';
      default:
        return 'shirt';
    }
  }

  /// Publishes a saved project to the community feed.
  static Future<bool> publishProject({
    required String projectId,
    required String name,
    required String templateType,
    String? thumbnailUrl,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final projectData = await ProjectRepository.loadProject(projectId);
      if (projectData == null) return false;

      await _supabase.from('published_designs').upsert({
        'id': projectId,
        'user_id': userId,
        'name': name,
        'category': categoryFromTemplate(templateType),
        'thumbnail_url': thumbnailUrl,
        'source_project_id': projectId,
        'design_data': {
          ...projectData,
          'source_project_id': projectId,
        },
        'updated_at': DateTime.now().toIso8601String(),
      });

      await ProjectRepository.setVisibility(projectId, 'public');
      return true;
    } catch (e) {
      debugPrint('[community_repository] publishProject: $e');
      return false;
    }
  }

  static Future<bool> isLiked(String designId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      final row = await _supabase
          .from('design_likes')
          .select('design_id')
          .eq('user_id', userId)
          .eq('design_id', designId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint('[community_repository] isLiked: $e');
      return false;
    }
  }

  /// Returns new liked state, or null on error.
  static Future<bool?> toggleLike(String designId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final existing = await _supabase
          .from('design_likes')
          .select('design_id')
          .eq('user_id', userId)
          .eq('design_id', designId)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('design_likes')
            .delete()
            .eq('user_id', userId)
            .eq('design_id', designId);
        return false;
      }

      await _supabase.from('design_likes').insert({
        'user_id': userId,
        'design_id': designId,
      });
      return true;
    } catch (e) {
      debugPrint('[community_repository] toggleLike: $e');
      return null;
    }
  }

  static Future<bool> isSaved(String designId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      final row = await _supabase
          .from('saved_designs')
          .select('design_id')
          .eq('user_id', userId)
          .eq('design_id', designId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint('[community_repository] isSaved: $e');
      return false;
    }
  }

  /// Returns new saved state, or null on error.
  static Future<bool?> toggleSave(String designId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final existing = await _supabase
          .from('saved_designs')
          .select('design_id')
          .eq('user_id', userId)
          .eq('design_id', designId)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('saved_designs')
            .delete()
            .eq('user_id', userId)
            .eq('design_id', designId);
        return false;
      }

      await _supabase.from('saved_designs').insert({
        'user_id': userId,
        'design_id': designId,
      });
      return true;
    } catch (e) {
      debugPrint('[community_repository] toggleSave: $e');
      return null;
    }
  }

  /// Bookmarks saved by the current user (with published design details).
  static Future<List<Map<String, dynamic>>> fetchSavedDesigns() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final rows = await _supabase
          .from('saved_designs')
          .select('design_id, created_at, published_designs(*, profiles(username, display_name, avatar_path))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(rows);
      return list.map((row) {
        final design = row['published_designs'];
        if (design is! Map<String, dynamic>) return null;
        return {
          ...design,
          'saved_at': row['created_at'],
          '_source': 'community',
        };
      }).whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('[community_repository] fetchSavedDesigns: $e');
      return [];
    }
  }

  /// Copies published design_data into a new project for the current user.
  static Future<String?> forkDesignToNewProject(Map<String, dynamic> design) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final rawData = design['design_data'];
      if (rawData is! Map<String, dynamic>) return null;
      if (rawData['parts'] == null) return null;

      final newId = generateProjectId();
      final templateType = rawData['template_type'] as String? ??
          design['template_type'] as String? ??
          'classic_shirt';
      final name = '${design['name'] as String? ?? 'Design'} (Remix)';

      final saved = await ProjectRepository.saveProject(
        projectId: newId,
        name: name,
        templateType: templateType,
        projectData: Map<String, dynamic>.from(rawData),
      );

      return saved != null ? newId : null;
    } catch (e) {
      debugPrint('[community_repository] forkDesignToNewProject: $e');
      return null;
    }
  }

  static ClothingTemplateType templateTypeFromDesign(Map<String, dynamic> design) {
    final rawData = design['design_data'];
    String? type;
    if (rawData is Map<String, dynamic>) {
      type = rawData['template_type'] as String?;
    }
    type ??= design['template_type'] as String?;
    type ??= design['category'] as String?;
    return ClothingTemplateTypeX.fromString(type ?? '') ??
        _categoryToTemplate(type);
  }

  static ClothingTemplateType _categoryToTemplate(String? category) {
    switch (category) {
      case 'pants':
        return ClothingTemplateType.blankPants;
      case 'tshirt':
        return ClothingTemplateType.blankTShirt;
      default:
        return ClothingTemplateType.blankShirt;
    }
  }
}
