import 'dart:ui';
import 'package:billing/billing.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../editor/data/editor_route_params.dart';
import '../../../templates/data/template_item_model.dart';
import '../../../../config/app_config.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../routing/shell_tab_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with LazyShellTabLoader {
  @override
  int get shellBranchIndex => 0;

  final PageController _bannerController = PageController();
  int _currentBannerPage = 0;
  List<Map<String, dynamic>> _trendingTemplates = [];
  bool _loadingTrending = false;

  @override
  void onLazyTabLoad() {
    _fetchTrendingTemplates();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _fetchTrendingTemplates() async {
    try {
      final res = await Supabase.instance.client
          .from('clothing_templates')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .limit(4);
      if (mounted) {
        setState(() {
          _trendingTemplates = List<Map<String, dynamic>>.from(res);
          _loadingTrending = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch trending: $e');
      if (mounted) setState(() => _loadingTrending = false);
    }
  }

  ClothingTemplateType _resolveClothingType(String dbType) {
    switch (dbType) {
      case 'classic_pants':
        return ClothingTemplateType.blankPants;
      case 'classic_tshirt':
        return ClothingTemplateType.blankTShirt;
      default:
        return ClothingTemplateType.blankShirt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 32),
                  Text(
                    AppLocalizations.of(context).homeTitle,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                  ),
                  const SizedBox(height: 28),
                  _buildBannerCarousel(),
                  const SizedBox(height: 32),
                  _buildClothesTypeSection(context),
                ],
              ),
            ),
          ),
          _buildTrendingHeader(context),
          if (_loadingTrending)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (_trendingTemplates.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).noTemplatesYet,
                    style: TextStyle(
                      color: AppColors.outlineVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTrendingCard(context, _trendingTemplates[index]),
                  childCount: _trendingTemplates.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.78,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // ─── App Bar (Performant — no BackdropFilter) ─────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 24.0),
        child: Center(
          child: GestureDetector(
            onTap: () => context.push('/settings'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceContainerLow,
                border:
                    Border.all(color: AppColors.surfaceContainerLowest, width: 2),
              ),
              child:
                  Icon(Icons.person, color: AppColors.outlineVariant),
            ),
          ),
        ),
      ),
      leadingWidth: 56,
      centerTitle: false,
      titleSpacing: 0,
      title: Row(
        children: [
          const BrandLogo(size: 24, borderRadius: 6),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppConfig.appNameShort,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    fontSize: 17,
                  ),
            ),
          ),
        ],
      ),
      actions: [
        const SubscriptionPill(),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ─── Banner Carousel ──────────────────────────────────────────────────

  Widget _buildBannerCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView(
            controller: _bannerController,
            onPageChanged: (i) => setState(() => _currentBannerPage = i),
            children: [
              _buildBannerCard(
                title: 'Hazır Skinleri\nKeşfet',
                subtitle: 'Hemen kullanılabilir skinler',
                buttonLabel: 'Keşfet',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF793A), Color(0xFF9F3B00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                icon: Icons.explore,
                onTap: () => context.push('/templates'),
              ),
              _buildBannerCard(
                title: 'Kendi Kıyafetini\nTasarla',
                subtitle: 'Sıfırdan oluştur',
                buttonLabel: 'Başla',
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                icon: Icons.brush,
                onTap: () => context.push(
                  '/editor',
                  extra: EditorRouteParams(
                    mode: EditorMode.classicClothingBlankStart,
                    clothingTemplate: ClothingTemplateType.blankShirt,
                  ),
                ),
              ),
              _buildBannerCard(
                title: 'Premium\nKoleksiyon',
                subtitle: 'Özel tasarımlar',
                buttonLabel: 'İncele',
                gradient: const LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                icon: Icons.star,
                onTap: () => context.push('/templates'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final isActive = _currentBannerPage == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary
                    : AppColors.outlineVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBannerCard({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required Gradient gradient,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background icon
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              size: 120,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          buttonLabel,
                          style: const TextStyle(
                            color: Color(0xFF2D2F2D),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward,
                            size: 16, color: Color(0xFF2D2F2D)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Clothes Type Section ─────────────────────────────────────────────

  Widget _buildClothesTypeSection(BuildContext context) {
    final items = [
      (
        icon: Icons.crop_portrait,
        label: 'T-Shirt',
        gradient: const LinearGradient(
          colors: [Color(0xFFFF793A), Color(0xFFFF9A5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        template: ClothingTemplateType.blankTShirt,
      ),
      (
        icon: Icons.checkroom,
        label: 'Shirt',
        gradient: const LinearGradient(
          colors: [Color(0xFF9F3B00), Color(0xFFBF5D20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        template: ClothingTemplateType.blankShirt,
      ),
      (
        icon: Icons.straighten,
        label: 'Pants',
        gradient: const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        template: ClothingTemplateType.blankPants,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kıyafet Türü',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          children: items.map((item) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: item != items.last ? 12.0 : 0,
                ),
                child: GestureDetector(
                  onTap: () => context.push(
                    '/editor',
                    extra: EditorRouteParams(
                      mode: EditorMode.classicClothingBlankStart,
                      clothingTemplate: item.template,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: item.gradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Trending Section ─────────────────────────────────────────────────

  Widget _buildTrendingHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Trending',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            GestureDetector(
              onTap: () => context.push('/templates'),
              child: Text(
                AppLocalizations.of(context).homeViewAll,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingCard(BuildContext context, Map<String, dynamic> row) {
    final name = row['name'] as String? ?? '';
    final templateType = row['template_type'] as String? ?? '';
    final isPro = row['is_pro'] == true;
    final imageUrl = (row['shirt_texture_url'] as String?) ??
        (row['preview_front_url'] as String?);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          final template = TemplateItemModel(
            templateId: row['id'] as String,
            title: name,
            type: TemplateType.classicClothing,
            clothingTemplate: _resolveClothingType(templateType),
            icon: Icons.checkroom,
            accentColor: const Color(0xFFFF793A),
            shirtAssetPath: row['shirt_texture_url'] as String?,
            pantsAssetPath: row['pants_texture_url'] as String?,
            thumbnailAsset: row['shirt_texture_url'] as String?,
            previewAsset: row['preview_front_url'] as String?,
            isPro: isPro,
          );
          context.push('/template-preview', extra: template);
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 300,
                          placeholder: (_, __) => _trendingPlaceholder(),
                          errorWidget: (_, __, ___) => _trendingPlaceholder(),
                        )
                      : _trendingPlaceholder(),
                ),
              ),
              if (isPro)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF793A), Color(0xFF9F3B00)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF9F3B00).withOpacity(0.95),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        templateType,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trendingPlaceholder() {
    return Container(
      color: const Color(0xFFFF793A).withOpacity(0.1),
      child: const Center(
        child: Icon(Icons.checkroom, size: 44, color: Color(0xFFFF793A)),
      ),
    );
  }
}
