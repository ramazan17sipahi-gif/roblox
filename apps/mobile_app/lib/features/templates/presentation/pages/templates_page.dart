import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/access_tier.dart';
import '../../data/catalog_likes_repository.dart';
import '../../data/template_item_model.dart';
import '../widgets/access_tier_badge.dart';
import '../widgets/catalog_like_button.dart';
import '../widgets/worn_character_preview.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Templates page — shows admin-curated character templates organized
/// by collections and categories. Users can browse, preview and open
/// templates directly in the editor.
class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  final _searchController = TextEditingController();
  int _selectedCollectionIndex = 0;
  bool _searchVisible = false;
  String _searchQuery = '';

  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;

  // Collections derived from template_type / pro flag
  static const _collections = [
    _Collection('All', Icons.grid_view_rounded, filter: _CollectionFilter.all),
    _Collection('Shirts', Icons.checkroom, filter: _CollectionFilter.shirt),
    _Collection('Pants', Icons.straighten, filter: _CollectionFilter.pants),
    _Collection('T-Shirts', Icons.crop_portrait, filter: _CollectionFilter.tshirt),
    _Collection('Sets', Icons.style, filter: _CollectionFilter.set),
    _Collection('Ad', Icons.play_circle_fill, filter: _CollectionFilter.ad),
    _Collection('Pro', Icons.workspace_premium, filter: _CollectionFilter.pro),
  ];

  @override
  void initState() {
    super.initState();
    CatalogLikesController.instance.ensureLoaded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchTemplates();
    });
  }

  Future<void> _fetchTemplates() async {
    try {
      final res = await Supabase.instance.client
          .from('clothing_templates')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      if (mounted) {
        setState(() {
          _templates = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch templates: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredTemplates {
    var items = _templates;

    if (_selectedCollectionIndex > 0) {
      final filter = _collections[_selectedCollectionIndex].filter;
      items = items.where((t) {
        final type = t['template_type'] as String? ?? '';
        final tier = AccessTier.fromRow(t);
        switch (filter) {
          case _CollectionFilter.shirt:
            return type == 'classic_shirt';
          case _CollectionFilter.pants:
            return type == 'classic_pants';
          case _CollectionFilter.tshirt:
            return type == 'classic_tshirt';
          case _CollectionFilter.set:
            return type == 'classic_set';
          case _CollectionFilter.ad:
            return tier == AccessTier.ad;
          case _CollectionFilter.pro:
            return tier == AccessTier.pro;
          case _CollectionFilter.all:
            return true;
        }
      }).toList();
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return items;

    return items.where((t) {
      final name = (t['name'] as String? ?? '').toLowerCase();
      final description = (t['description'] as String? ?? '').toLowerCase();
      final type = (t['template_type'] as String? ?? '').toLowerCase();
      return name.contains(query) || description.contains(query) || type.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).templatesBrowseTitle,
                                style: TextStyle(
                                  color: AppColors.onBackground,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context).templatesBrowseSubtitle,
                                style: TextStyle(
                                  color: AppColors.onBackground.withOpacity(0.5),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildSearchIcon(),
                      ],
                    ),
                    if (_searchVisible) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).templatesSearchHint,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _searchVisible = false;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.surfaceContainerHigh),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.surfaceContainerHigh),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Pro Banner ──
            SliverToBoxAdapter(child: _buildProBanner()),

            // ── Collection Chips ──
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _collections.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final isSelected = i == _selectedCollectionIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCollectionIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surfaceContainerHigh,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _collections[i].icon,
                              size: 16,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.onBackground.withOpacity(0.4),
                            ),
                            SizedBox(width: 6),
                            Text(
                              _collections[i].name,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.onBackground.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Templates Grid ──
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredTemplates.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.checkroom_rounded,
                        size: 48,
                        color: AppColors.outlineVariant,
                      ),
                      SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context).noTemplatesYet,
                        style: TextStyle(
                          color: AppColors.onBackground.withOpacity(0.5),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _buildTemplateCard(_filteredTemplates[i]),
                    childCount: _filteredTemplates.length,
                  ),
                ),
              ),

            // Bottom padding for bottom nav
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchIcon() {
    return GestureDetector(
      onTap: () => setState(() => _searchVisible = !_searchVisible),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceContainerHigh),
        ),
        child: Icon(
          Icons.search_rounded,
          color: AppColors.onBackground.withOpacity(0.5),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildProBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).templatesUnlimitedAccess,
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => context.push('/paywall'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context).templatesGetStarted,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> row) {
    final String name = row['name'] as String? ?? '';
    final String templateType = row['template_type'] as String? ?? '';
    final accessTier = AccessTier.fromRow(row);
    final typeLabel = TemplateItemModel.catalogTypeLabel(templateType);
    final templateId = (row['id'] ?? '').toString();

    return ListenableBuilder(
      listenable: CatalogLikesController.instance,
      builder: (context, _) {
        final likes = CatalogLikesController.instance;
        final liked = likes.isLiked(templateId);
        final count = likes.countFor(
          templateId,
          CatalogLikesRepository.parseCount(row['likes_count']),
        );
        return GestureDetector(
          onTap: () {
            context.push(
              '/template-preview',
              extra: TemplateItemModel.fromClothingTemplateRow(row),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          child: WornCharacterPreview.fromTemplateRow(row),
                        ),
                      ),
                      if (accessTier.isGated)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: AccessTierBadge(tier: accessTier),
                        )
                      else
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                color: AppColors.onBackground,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CatalogLikeButton(
                          liked: liked,
                          onTap: () => handleCatalogLikeTap(
                            context: context,
                            templateId: templateId,
                            knownCount: count,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.onBackground,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: const TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _CollectionFilter { all, shirt, pants, tshirt, set, ad, pro }

class _Collection {
  final String name;
  final IconData icon;
  final _CollectionFilter filter;
  const _Collection(this.name, this.icon, {required this.filter});
}
