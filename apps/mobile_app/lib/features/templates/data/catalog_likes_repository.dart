import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Likes on catalog skins (`clothing_templates`). Liked rows appear in Library → Saved.
class CatalogLikesRepository {
  static final _supabase = Supabase.instance.client;

  static int parseCount(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static Future<Set<String>> fetchLikedIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};
      final rows = await _supabase
          .from('template_likes')
          .select('template_id')
          .eq('user_id', userId);
      return {
        for (final row in List<Map<String, dynamic>>.from(rows))
          if (row['template_id'] != null) row['template_id'].toString(),
      };
    } catch (e) {
      debugPrint('[catalog_likes] fetchLikedIds: $e');
      return {};
    }
  }

  /// Liked catalog templates for Library → Saved.
  static Future<List<Map<String, dynamic>>> fetchLikedTemplates() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final rows = await _supabase
          .from('template_likes')
          .select('created_at, clothing_templates(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows)
          .map((row) {
            final template = row['clothing_templates'];
            if (template is! Map<String, dynamic>) return null;
            return {
              ...template,
              'saved_at': row['created_at'],
              '_source': 'catalog',
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[catalog_likes] fetchLikedTemplates: $e');
      return [];
    }
  }

  /// Returns the new liked state, or null on error / signed-out.
  static Future<bool?> toggle(String templateId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final existing = await _supabase
          .from('template_likes')
          .select('template_id')
          .eq('user_id', userId)
          .eq('template_id', templateId)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('template_likes')
            .delete()
            .eq('user_id', userId)
            .eq('template_id', templateId);
        return false;
      }

      await _supabase.from('template_likes').insert({
        'user_id': userId,
        'template_id': templateId,
      });
      return true;
    } catch (e) {
      debugPrint('[catalog_likes] toggle: $e');
      return null;
    }
  }
}

/// In-memory like state shared by Home, Templates, Preview, and Library.
class CatalogLikesController extends ChangeNotifier {
  CatalogLikesController._();
  static final instance = CatalogLikesController._();

  final Set<String> likedIds = {};
  final Map<String, int> countOverrides = {};
  Future<void>? _loading;

  bool isSignedIn() =>
      Supabase.instance.client.auth.currentUser != null;

  bool isLiked(String templateId) => likedIds.contains(templateId);

  int countFor(String templateId, int fallback) =>
      countOverrides[templateId] ?? fallback;

  Future<void> ensureLoaded() {
    _loading ??= _load();
    return _loading!;
  }

  Future<void> reload() {
    _loading = _load();
    return _loading!;
  }

  Future<void> _load() async {
    likedIds
      ..clear()
      ..addAll(await CatalogLikesRepository.fetchLikedIds());
    notifyListeners();
  }

  Future<bool?> toggle(String templateId, {int? knownCount}) async {
    final next = await CatalogLikesRepository.toggle(templateId);
    if (next == null) return null;
    if (next) {
      likedIds.add(templateId);
    } else {
      likedIds.remove(templateId);
    }
    final base = knownCount ?? countOverrides[templateId];
    if (base != null) {
      final updated = base + (next ? 1 : -1);
      countOverrides[templateId] = updated < 0 ? 0 : updated;
    }
    notifyListeners();
    return next;
  }
}
