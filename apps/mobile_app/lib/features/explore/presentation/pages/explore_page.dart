import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../templates/data/template_item_model.dart';
import '../../../editor/data/editor_route_params.dart';
import '../../data/community_repository.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  int _selectedCategory = 0;
  String _sortBy = 'trending';
  String _searchQuery = '';
  List<Map<String, dynamic>> _designs = [];
  List<Map<String, dynamic>> _allDesigns = [];
  bool _isLoading = true;

  final _categories = [
    ('All', Icons.grid_view),
    ('Shirts', Icons.checkroom),
    ('Pants', Icons.straighten),
    ('T-Shirts', Icons.crop_portrait),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDesigns();
    });
  }

  Future<void> _loadDesigns() async {
    setState(() => _isLoading = true);
    try {
      // Try published_designs first (community designs)
      var query = Supabase.instance.client
          .from('published_designs')
          .select('*, profiles(username, display_name, avatar_path)');

      if (_selectedCategory > 0) {
        final categoryNames = ['', 'shirt', 'pants', 'tshirt'];
        query = query.eq('category', categoryNames[_selectedCategory]);
      }

      final response = await query
          .order(_sortBy == 'trending' ? 'likes_count' : 'created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _allDesigns = List<Map<String, dynamic>>.from(response);
          _designs = _filterDesigns(_allDesigns);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[explore_page] published_designs error: $e');
      // Fallback: load from clothing_templates
      await _loadFromTemplates();
    }
  }

  Future<void> _loadFromTemplates() async {
    try {
      var query = Supabase.instance.client
          .from('clothing_templates')
          .select()
          .eq('is_active', true);

      if (_selectedCategory > 0) {
        final typeFilters = ['', 'classic_shirt', 'classic_pants', 'classic_tshirt'];
        if (_selectedCategory < typeFilters.length) {
          query = query.eq('template_type', typeFilters[_selectedCategory]);
        }
      }

      final response = await query.order('sort_order', ascending: true).limit(50);

      if (mounted) {
        setState(() {
          _allDesigns = List<Map<String, dynamic>>.from(response).map((row) => {
            'id': row['id'],
            'name': row['name'] ?? 'Untitled',
            'thumbnail_url': row['preview_front_url'] ?? row['shirt_texture_url'],
            'category': _mapTemplateType(row['template_type'] as String? ?? ''),
            'template_type': row['template_type'],
            'likes_count': row['download_count'] ?? 0,
            'comments_count': 0,
            'is_pro': row['is_pro'] ?? false,
            'shirt_texture_url': row['shirt_texture_url'],
            'pants_texture_url': row['pants_texture_url'],
            'preview_front_url': row['preview_front_url'],
            'created_at': row['created_at'],
            '_source': 'templates',
          }).toList();
          _designs = _filterDesigns(_allDesigns);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[explore_page] clothing_templates error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapTemplateType(String dbType) {
    switch (dbType) {
      case 'classic_pants': return 'pants';
      case 'classic_tshirt': return 'tshirt';
      case 'classic_shirt':
      case 'classic_set':
      default: return 'shirt';
    }
  }

  List<Map<String, dynamic>> _filterDesigns(List<Map<String, dynamic>> source) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return source;

    return source.where((design) {
      final name = (design['name'] as String? ?? '').toLowerCase();
      final category = (design['category'] as String? ?? '').toLowerCase();
      final profile = design['profiles'];
      String author = '';
      if (profile is Map) {
        author = (profile['display_name'] as String? ?? profile['username'] as String? ?? '').toLowerCase();
      }
      return name.contains(query) || category.contains(query) || author.contains(query);
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _designs = _filterDesigns(_allDesigns);
    });
  }

  ClothingTemplateType _resolveClothingType(String dbType) {
    switch (dbType) {
      case 'classic_pants': return ClothingTemplateType.blankPants;
      case 'classic_tshirt': return ClothingTemplateType.blankTShirt;
      default: return ClothingTemplateType.blankShirt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadDesigns,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // ── Header ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(AppLocalizations.of(context)!.exploreDiscover, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.onSurface)),
                          ),
                          _sortChip('Trending', 'trending'),
                          SizedBox(width: 6),
                          _sortChip('New', 'created_at'),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _showFilterSheet,
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.tune, size: 18, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Search ──
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextField(
                          style: TextStyle(fontSize: 14),
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.exploreSearchCreators,
                            hintStyle: TextStyle(color: AppColors.outlineVariant.withValues(alpha: 0.5), fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: AppColors.outlineVariant, size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Category chips ──
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final isActive = index == _selectedCategory;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedCategory = index);
                                _loadDesigns();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.primary : AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(18),
                                  border: isActive ? null : Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(cat.$2, size: 14, color: isActive ? Colors.white : AppColors.outlineVariant),
                                    SizedBox(width: 4),
                                    Text(cat.$1, style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700,
                                      color: isActive ? Colors.white : AppColors.onSurface,
                                    )),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 20),

                      // ── Results count ──
                      Text(
                        '${_designs.length} designs',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.outlineVariant.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Grid ──
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_designs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checkroom, size: 56, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                        SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context)!.noDesignsYet,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.outlineVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _DesignCard(
                        design: _designs[index],
                        onTap: () => _onDesignTap(_designs[index]),
                        onLike: () => _onLike(_designs[index]),
                      ),
                      childCount: _designs.length,
                    ),
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final isActive = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() => _sortBy = value);
        _loadDesigns();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: isActive ? AppColors.primary : AppColors.outlineVariant,
        )),
      ),
    );
  }

  void _onDesignTap(Map<String, dynamic> design) {
    try {
      // If from templates source, open template preview
      if (design['_source'] == 'templates') {
        final template = TemplateItemModel(
          templateId: design['id']?.toString() ?? '',
          title: design['name']?.toString() ?? 'Untitled',
          type: TemplateType.classicClothing,
          clothingTemplate: _resolveClothingType(
            design['template_type']?.toString() ?? '',
          ),
          icon: Icons.checkroom,
          accentColor: const Color(0xFFFF793A),
          shirtAssetPath: design['shirt_texture_url'] as String?,
          pantsAssetPath: design['pants_texture_url'] as String?,
          thumbnailAsset: design['thumbnail_url'] as String?,
          previewAsset: design['preview_front_url'] as String?,
          isPro: design['is_pro'] == true,
        );
        context.push('/template-preview', extra: template);
      } else {
        // Community design — show detail
        context.push('/design_detail', extra: Map<String, dynamic>.from(design));
      }
    } catch (e, st) {
      debugPrint('[explore_page] tap failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open item: $e')),
      );
    }
  }

  void _onLike(Map<String, dynamic> design) async {
    if (design['_source'] == 'templates') return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final designId = design['id'] as String?;
      if (designId == null) return;

      final newState = await CommunityRepository.toggleLike(designId);
      if (newState == null || !mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save like. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        design['likes_count'] = (design['likes_count'] as int? ?? 0) + (newState ? 1 : -1);
        if ((design['likes_count'] as int) < 0) design['likes_count'] = 0;
      });
    } catch (e) {
      debugPrint('[explore_page] like catch: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save like. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showFilterSheet() {
    String selectedSort = _sortBy == 'trending' ? 'Popular' : 'Recent';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 48, height: 4, decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(4)))),
              SizedBox(height: 24),
              Text(AppLocalizations.of(context)!.exploreSortFilter, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Text(AppLocalizations.of(context)!.exploreSortBy, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.outlineVariant)),
              SizedBox(height: 12),
              ...['Popular', 'Recent', 'Most Liked', 'Top Rated'].map((opt) => GestureDetector(
                onTap: () => setSheetState(() => selectedSort = opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: selectedSort == opt ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: selectedSort == opt ? Border.all(color: AppColors.primary) : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(opt, style: TextStyle(fontWeight: FontWeight.w700, color: selectedSort == opt ? AppColors.primary : AppColors.onSurface)),
                      if (selectedSort == opt) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _sortBy = selectedSort == 'Popular' ? 'trending' : 'created_at');
                  _loadDesigns();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(gradient: AppColors.actionGradient, borderRadius: BorderRadius.circular(30)),
                  child: Center(child: Text(AppLocalizations.of(context)!.exploreApplyFilter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Design card widget for the explore grid.
class _DesignCard extends StatelessWidget {
  final Map<String, dynamic> design;
  final VoidCallback onTap;
  final VoidCallback onLike;

  const _DesignCard({
    required this.design,
    required this.onTap,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final profile = design['profiles'] as Map<String, dynamic>?;
    final isTemplate = design['_source'] == 'templates';
    final username = isTemplate
        ? 'Official'
        : ((profile?['username'] as String?) ?? 'Unknown');
    final likes = design['likes_count'] ?? 0;
    final comments = design['comments_count'] ?? 0;
    final thumbnailUrl = design['thumbnail_url'] as String?;
    final isPro = design['is_pro'] as bool? ?? false;
    final category = design['category'] as String? ?? '';

    final cardColor = _getCategoryColor(category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      color: AppColors.surfaceContainerLow,
                    ),
                    child: thumbnailUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.network(
                              thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  _getCategoryIcon(category),
                                  size: 48,
                                  color: cardColor.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              _getCategoryIcon(category),
                              size: 48,
                              color: cardColor.withValues(alpha: 0.3),
                            ),
                          ),
                  ),
                  // PRO badge
                  if (isPro)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF793A), Color(0xFF9F3B00)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.workspace_premium, color: Colors.white, size: 10),
                            SizedBox(width: 3),
                            Text('PRO', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  // Category tag
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getCategoryLabel(category),
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: cardColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                design['name'] ?? 'Untitled',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface),
              ),
            ),
            // Author + stats
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 8,
                    backgroundColor: cardColor.withValues(alpha: 0.2),
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: cardColor),
                    ),
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(username, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: AppColors.outlineVariant.withValues(alpha: 0.7))),
                  ),
                  // Like button
                  GestureDetector(
                    onTap: onLike,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border, size: 13, color: AppColors.outlineVariant),
                        SizedBox(width: 2),
                        Text('$likes', style: TextStyle(fontSize: 10, color: AppColors.outlineVariant.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                  SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.outlineVariant),
                      SizedBox(width: 2),
                      Text('$comments', style: TextStyle(fontSize: 10, color: AppColors.outlineVariant.withValues(alpha: 0.7))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'shirt': return const Color(0xFF9F3B00);
      case 'pants': return const Color(0xFF00897B);
      case 'tshirt': return const Color(0xFFFF793A);
      default: return const Color(0xFF9F3B00);
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'shirt': return 'Shirt';
      case 'pants': return 'Pants';
      case 'tshirt': return 'T-Shirt';
      default: return 'Clothing';
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'shirt': return Icons.checkroom;
      case 'pants': return Icons.straighten;
      case 'tshirt': return Icons.crop_portrait;
      default: return Icons.checkroom;
    }
  }
}
