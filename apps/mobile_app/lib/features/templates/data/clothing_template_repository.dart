import 'package:supabase_flutter/supabase_flutter.dart';
import '../../editor/data/editor_route_params.dart';

/// Model for a clothing template fetched from Supabase.
class ClothingTemplateModel {
  final String id;
  final String name;
  final String slug;
  final String templateType; // 'classic_shirt' | 'classic_pants' | 'classic_tshirt'
  final String? description;
  final String? coverImageUrl;
  final bool isActive;
  final bool isPro;
  final int sortOrder;

  const ClothingTemplateModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.templateType,
    this.description,
    this.coverImageUrl,
    this.isActive = true,
    this.isPro = false,
    this.sortOrder = 0,
  });

  factory ClothingTemplateModel.fromJson(Map<String, dynamic> json) {
    return ClothingTemplateModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      templateType: json['template_type'] as String,
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isPro: json['is_pro'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  /// Map to the local [ClothingTemplateType] enum.
  ClothingTemplateType? get clothingTemplateType =>
      ClothingTemplateTypeX.fromString(templateType);
}

/// Model for sticker categories.
class StickerCategoryModel {
  final String id;
  final String name;
  final String slug;
  final String? iconName;
  final int sortOrder;
  final List<StickerModel> stickers;

  const StickerCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.iconName,
    this.sortOrder = 0,
    this.stickers = const [],
  });

  factory StickerCategoryModel.fromJson(Map<String, dynamic> json, {List<StickerModel>? stickers}) {
    return StickerCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      iconName: json['icon_name'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      stickers: stickers ?? [],
    );
  }
}

/// Model for individual stickers.
class StickerModel {
  final String id;
  final String categoryId;
  final String name;
  final String imageUrl;
  final bool isPro;
  final int sortOrder;

  const StickerModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.imageUrl,
    this.isPro = false,
    this.sortOrder = 0,
  });

  factory StickerModel.fromJson(Map<String, dynamic> json) {
    return StickerModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String,
      isPro: json['is_pro'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

/// Repository for fetching clothing templates and stickers from Supabase.
/// Uses anon key (public read via RLS).
class ClothingTemplateRepository {
  final SupabaseClient _client;

  ClothingTemplateRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch all active clothing templates, ordered by sort_order.
  Future<List<ClothingTemplateModel>> fetchActiveTemplates() async {
    final response = await _client
        .from('clothing_templates')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return (response as List)
        .map((row) => ClothingTemplateModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetch all active sticker categories with their stickers.
  Future<List<StickerCategoryModel>> fetchStickerCategories() async {
    final catResponse = await _client
        .from('sticker_categories')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final stkResponse = await _client
        .from('stickers')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final categories = (catResponse as List)
        .map((row) => row as Map<String, dynamic>)
        .toList();
    final stickers = (stkResponse as List)
        .map((row) => StickerModel.fromJson(row as Map<String, dynamic>))
        .toList();

    return categories.map((cat) {
      final catId = cat['id'] as String;
      return StickerCategoryModel.fromJson(
        cat,
        stickers: stickers.where((s) => s.categoryId == catId).toList(),
      );
    }).toList();
  }
}
