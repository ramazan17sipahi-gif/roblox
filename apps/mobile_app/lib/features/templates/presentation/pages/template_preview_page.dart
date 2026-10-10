import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:billing/billing.dart';
import '../../../ads/ads_providers.dart';
import '../../../ads/data/skin_access_gate.dart';
import '../../data/access_tier.dart';
import '../../data/catalog_likes_repository.dart';
import '../widgets/access_tier_badge.dart';
import '../widgets/catalog_like_button.dart';
import '../../../editor/data/editor_route_params.dart';
import '../../../editor/presentation/widgets/threejs_preview.dart';
import '../../data/skin_download_service.dart';
import '../../data/template_item_model.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Full-screen template preview page — mandatory step before entering editor.
///
/// Shows a hero preview image, template metadata, and a single CTA button.
/// Ad rank: free users get a modal (watch ads OR get Pro).
/// Pro rank: subscription only — ads cannot unlock.
///
/// Navigation contract:
/// - Incoming: `context.push('/template-preview', extra: TemplateItemModel)`
/// - CTA: `context.pushReplacement('/editor', extra: EditorRouteParams)`
///   → pushReplacement ensures no preview-loop on back from editor.
/// - Back: standard pop → returns to originating list/page.
class TemplatePreviewPage extends ConsumerStatefulWidget {
  final TemplateItemModel template;

  const TemplatePreviewPage({super.key, required this.template});

  @override
  ConsumerState<TemplatePreviewPage> createState() => _TemplatePreviewPageState();
}

class _TemplatePreviewPageState extends ConsumerState<TemplatePreviewPage> {
  final GlobalKey<ThreeJSPreviewState> _threejsKey = GlobalKey<ThreeJSPreviewState>();
  String? _downloadBusy;

  TemplateItemModel get template => widget.template;

  @override
  void initState() {
    super.initState();
    CatalogLikesController.instance.ensureLoaded();
    ref.read(rewardedAdServiceProvider).initialize();
  }

  /// Whether this template has pre-designed clothing textures.
  bool get _hasClothingTextures =>
      template.shirtAssetPath != null || template.pantsAssetPath != null;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Top bar ──
          _buildTopBar(context),

          // ── Scrollable content ──
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero preview area
                  _buildHeroPreview(context),

                  const SizedBox(height: 24),

                  // Template info
                  _buildTemplateInfo(context),

                  const SizedBox(height: 16),

                  // Details card
                  _buildDetailsCard(context),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── Bottom CTA ──
          _buildBottomCTA(context, bottomPad),
        ],
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: 8,
        left: 10,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 22),
          ),
          Expanded(
            child: Text(
              AppLocalizations.of(context).templatePreviewTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
          ),
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _typeBadgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_typeBadgeIcon, size: 14, color: _typeBadgeColor),
                const SizedBox(width: 4),
                Text(
                  template.typeDisplayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _typeBadgeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _typeBadgeColor => const Color(0xFF7C4DFF);

  IconData get _typeBadgeIcon => Icons.checkroom;

  // ─── Hero Preview Area ────────────────────────────────────────────────

  Widget _buildHeroPreview(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final heroHeight = screenWidth * 0.85;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      height: heroHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: template.accentColor.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    template.accentColor.withOpacity(0.06),
                    template.accentColor.withOpacity(0.15),
                    template.accentColor.withOpacity(0.08),
                  ],
                ),
              ),
            ),
            // Image / Icon content — priority: previewAsset > thumbnailAsset > icon
            _buildPreviewContent(),
            if (template.accessTier.isGated)
              Positioned(
                top: 16,
                left: 16,
                child: AccessTierBadge(
                  tier: template.accessTier,
                  size: AccessTierBadgeSize.large,
                ),
              ),
            if (template.templateId.isNotEmpty)
              Positioned(
                top: 16,
                right: 16,
                child: ListenableBuilder(
                  listenable: CatalogLikesController.instance,
                  builder: (context, _) {
                    return CatalogLikeButton(
                      liked: CatalogLikesController.instance
                          .isLiked(template.templateId),
                      onTap: () => handleCatalogLikeTap(
                        context: context,
                        templateId: template.templateId,
                        knownCount: CatalogLikesController.instance.countFor(
                          template.templateId,
                          template.likesCount,
                        ),
                      ),
                    );
                  },
                ),
              ),
            // Category badge (bottom-left)
            if (template.category != null)
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    template.category!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: template.accentColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Preview content: for pre-designed sets with textures → live 3D mannequin;
  /// otherwise → static image or icon fallback.
  Widget _buildPreviewContent() {
    // Pre-designed clothing set — show live 3D mannequin with textures
    if (_hasClothingTextures) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ThreeJSPreview(
          key: _threejsKey,
          showControls: false,
          onModelReady: _applyClothingTexture,
        ),
      );
    }

    final bestImage = template.bestImageAsset;
    if (bestImage != null) {
      if (template.isBestImageNetwork) {
        return Image.network(
          bestImage,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildIconFallback(),
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: template.accentColor,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        );
      } else {
        return Image.asset(
          bestImage,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildIconFallback(),
        );
      }
    }
    return _buildIconFallback();
  }

  /// Apply shirt + pants textures separately to 3D mannequin.
  /// Pants applied first (legs), then shirt (torso+arms) — matches editor flow.
  Future<void> _applyClothingTexture() async {
    try {
      ui.Image? shirtImage;
      ui.Image? pantsImage;

      if (template.shirtAssetPath != null) {
        shirtImage = await _loadImage(template.shirtAssetPath!);
      }
      if (template.pantsAssetPath != null) {
        pantsImage = await _loadImage(template.pantsAssetPath!);
      }

      if (shirtImage == null && pantsImage == null) return;
      if (!mounted) return;

      // Apply pants FIRST (legs), then shirt (torso+arms).
      // This prevents shirt arm textures from overwriting leg regions.
      if (pantsImage != null) {
        final pantsBytes = await pantsImage.toByteData(format: ui.ImageByteFormat.png);
        if (pantsBytes != null && mounted) {
          final pantsB64 = base64Encode(pantsBytes.buffer.asUint8List());
          final opToken = _threejsKey.currentState?.beginOp(ViewerOpState.clothingApply) ?? 0;
          _threejsKey.currentState?.applyClassicTexture(
            pantsB64,
            'pants',
            opToken: opToken,
            resetOthers: false,
          );
        }
      }

      await Future.delayed(const Duration(milliseconds: 80));

      if (shirtImage != null && mounted) {
        final shirtBytes = await shirtImage.toByteData(format: ui.ImageByteFormat.png);
        if (shirtBytes != null && mounted) {
          final shirtB64 = base64Encode(shirtBytes.buffer.asUint8List());
          final opToken = _threejsKey.currentState?.beginOp(ViewerOpState.clothingApply) ?? 0;
          _threejsKey.currentState?.applyClassicTexture(
            shirtB64,
            'shirt',
            opToken: opToken,
            resetOthers: false,
          );
        }
      }

      // Single-piece fallback (only shirt OR only pants, no set)
      if (shirtImage == null && pantsImage != null) {
        // Already applied above as 'pants'
      } else if (pantsImage == null && shirtImage != null) {
        // Already applied above as 'shirt'
      }
    } catch (e) {
      debugPrint('Preview texture apply error: $e');
      _threejsKey.currentState?.endCurrentOp();
    }
  }

  /// Load a ui.Image from network URL or local asset path.
  Future<ui.Image?> _loadImage(String path) async {
    try {
      Uint8List bytes;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        final response = await http.get(Uri.parse(path));
        if (response.statusCode != 200) return null;
        bytes = response.bodyBytes;
      } else {
        final data = await rootBundle.load(path);
        bytes = data.buffer.asUint8List();
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('_loadImage error ($path): $e');
      return null;
    }
  }

  Widget _buildIconFallback() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: template.accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              template.icon,
              size: 48,
              color: template.accentColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Preview',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: template.accentColor.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Template Info ────────────────────────────────────────────────────

  Widget _buildTemplateInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListenableBuilder(
            listenable: CatalogLikesController.instance,
            builder: (context, _) {
              final likes = CatalogLikesController.instance;
              final liked = likes.isLiked(template.templateId);
              final count = likes.countFor(
                template.templateId,
                template.likesCount,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      template.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ),
                  if (template.templateId.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: CatalogLikeCount(
                        count: count,
                        liked: liked,
                        onTap: () => handleCatalogLikeTap(
                          context: context,
                          templateId: template.templateId,
                          knownCount: count,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.checkroom,
                size: 14,
                color: AppColors.outlineVariant,
              ),
              SizedBox(width: 4),
              Text(
                template.typeDisplayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.outlineVariant,
                ),
              ),
              if (template.category != null) ...[
                SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  template.category!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.outlineVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── Details Card ─────────────────────────────────────────────────────

  Widget _buildDetailsCard(BuildContext context) {
    final details = <_DetailRow>[];

    if (template.type == TemplateType.classicClothing &&
        template.clothingTemplate != null) {
      final ct = template.clothingTemplate!;
      details.addAll([
        _DetailRow(AppLocalizations.of(context).templateDetailSize, ct.subtitle),
        _DetailRow(
          AppLocalizations.of(context).templateDetailParts,
          template.previewActiveParts.join(', '),
        ),
        _DetailRow(
          AppLocalizations.of(context).templateDetailClass,
          template.robloxClassLabel,
        ),
      ]);
    } else {
      details.addAll([
        _DetailRow(AppLocalizations.of(context).templateDetailType, template.typeDisplayName),
        if (template.category != null) _DetailRow(AppLocalizations.of(context).templateDetailCategory, template.category!),
        _DetailRow(AppLocalizations.of(context).templateDetailMode, 'Classic Clothing Blank Start'),
      ]);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.1)),
      ),
      child: Column(
        children: details
            .map(
              (d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.outlineVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        d.value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─── Bottom CTA ───────────────────────────────────────────────────────

  Widget _buildBottomCTA(BuildContext context, double bottomPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad > 0 ? bottomPad : 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (template.hasShirtTexture || template.hasPantsTexture) ...[
            _buildDownloadRow(context),
            const SizedBox(height: 10),
          ],
          GestureDetector(
        onTap: () => _onCTATap(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: template.accessTier == AccessTier.pro
                ? const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF4444)])
                : template.accessTier == AccessTier.ad
                    ? const LinearGradient(
                        colors: [Color(0xFF00B4D8), Color(0xFF0077B6)])
                    : AppColors.actionGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (template.accessTier == AccessTier.pro
                        ? const Color(0xFFFF6B35)
                        : template.accessTier == AccessTier.ad
                            ? const Color(0xFF00B4D8)
                            : AppColors.primary)
                    .withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _needsUnlock
                    ? (template.accessTier == AccessTier.ad
                        ? Icons.play_circle_fill
                        : Icons.workspace_premium)
                    : Icons.brush,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                _needsUnlock
                    ? (template.accessTier == AccessTier.ad
                        ? AppLocalizations.of(context).templateAdAccess
                        : AppLocalizations.of(context).templateProAccess)
                    : AppLocalizations.of(context).templateUseDesign,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPro = ref.watch(canAccessProProvider);
    return Column(
      children: [
        Row(
          children: [
            if (template.hasShirtTexture)
              Expanded(
                child: _downloadChip(
                  context,
                  label: l10n.templateDownloadShirt,
                  busy: _downloadBusy == 'shirt',
                  enabled: _downloadBusy == null,
                  onTap: () => _downloadPiece(context, shirt: true),
                ),
              ),
            if (template.hasShirtTexture && template.hasPantsTexture)
              const SizedBox(width: 10),
            if (template.hasPantsTexture)
              Expanded(
                child: _downloadChip(
                  context,
                  label: l10n.templateDownloadPants,
                  busy: _downloadBusy == 'pants',
                  enabled: _downloadBusy == null,
                  onTap: () => _downloadPiece(context, shirt: false),
                ),
              ),
          ],
        ),
        if (!isPro) ...[
          const SizedBox(height: 6),
          Text(
            l10n.templateDownloadAdHint,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.outlineVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _downloadChip(
    BuildContext context, {
    required String label,
    required bool busy,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.download, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPiece(BuildContext context, {required bool shirt}) async {
    final l10n = AppLocalizations.of(context);
    final path = shirt ? template.shirtAssetPath : template.pantsAssetPath;
    if (path == null || path.isEmpty) return;

    final isPro = ref.read(canAccessProProvider);
    if (!isPro) {
      final earned = await ref.read(rewardedAdServiceProvider).showRewarded();
      if (!earned) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.templateDownloadAdFailed)),
          );
        }
        return;
      }
    }

    setState(() => _downloadBusy = shirt ? 'shirt' : 'pants');
    try {
      await SkinDownloadService.saveWatermarkedTexture(
        sourcePath: path,
        fileName: SkinDownloadService.fileNameFor(
          title: template.title,
          shirt: shirt,
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.templateDownloadSaved(
                shirt ? l10n.templateDownloadShirt : l10n.templateDownloadPants,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final denied = e.toString().contains('permission');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              denied
                  ? l10n.templateDownloadNeedPermission
                  : l10n.templateDownloadFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadBusy = null);
    }
  }

  bool get _needsUnlock {
    return !SkinAccessGate.isUnlocked(
      tier: template.accessTier,
      canAccessPro: ref.watch(canAccessProProvider),
      adUnlocked: ref.watch(isProSkinUnlockedProvider(template.templateId)),
    );
  }

  /// Ad rank: entitlement or rewarded ads. Pro rank: subscription only.
  Future<void> _onCTATap(BuildContext context) async {
    if (template.accessTier.isGated) {
      debugPrint('[skin_gate] tier=${template.accessTier.name} screen=TemplatePreviewPage');
      final unlocked = await SkinAccessGate.ensureUnlocked(
        context: context,
        ref: ref,
        tier: template.accessTier,
        templateId: template.templateId,
        templateTitle: template.title,
      );
      if (!unlocked || !context.mounted) return;
    }

    if (!context.mounted) return;
    // pushReplacement: removes preview from stack → editor back goes to Home/Templates
    context.pushReplacement('/editor', extra: template.toEditorParams());
  }
}

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}
