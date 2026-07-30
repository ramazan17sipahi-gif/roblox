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
import '../../../editor/data/editor_route_params.dart';
import '../../../editor/presentation/widgets/threejs_preview.dart';
import '../../data/template_item_model.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Full-screen template preview page — mandatory step before entering editor.
///
/// Shows a hero preview image, template metadata, and a single CTA button.
/// Pro gating is centralized here: if [template.isPro], CTA redirects to paywall.
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

  TemplateItemModel get template => widget.template;

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
            // Pro badge overlay
            if (template.isPro)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF4444)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Pro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
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
          _threejsKey.currentState?.applyClassicTexture(pantsB64, 'pants', opToken: opToken);
        }
      }

      await Future.delayed(const Duration(milliseconds: 80));

      if (shirtImage != null && mounted) {
        final shirtBytes = await shirtImage.toByteData(format: ui.ImageByteFormat.png);
        if (shirtBytes != null && mounted) {
          final shirtB64 = base64Encode(shirtBytes.buffer.asUint8List());
          final opToken = _threejsKey.currentState?.beginOp(ViewerOpState.clothingApply) ?? 0;
          _threejsKey.currentState?.applyClassicTexture(shirtB64, 'shirt', opToken: opToken);
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
          Text(
            template.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
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
        _DetailRow(AppLocalizations.of(context).templateDetailParts, ct.activeParts.join(', ')),
        _DetailRow(AppLocalizations.of(context).templateDetailClass, ct.robloxClassName),
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
                  children: [
                    Text(
                      d.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.outlineVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      d.value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
      child: GestureDetector(
        onTap: () => _onCTATap(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: template.isPro
                ? const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF4444)])
                : AppColors.actionGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (template.isPro
                        ? const Color(0xFFFF6B35)
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
                template.isPro && !ref.watch(canAccessProProvider)
                    ? Icons.workspace_premium
                    : Icons.brush,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                template.isPro && !ref.watch(canAccessProProvider)
                    ? AppLocalizations.of(context).templateProAccess
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
    );
  }

  /// Centralized pro gating — entitlement-aware.
  ///
  /// isPro && user has access => editor
  /// isPro && free user => paywall
  /// !isPro => editor
  void _onCTATap(BuildContext context) {
    if (template.isPro) {
      final canAccess = ref.read(canAccessProProvider);
      if (!canAccess) {
        debugPrint('[pro_gate_blocked] feature=template_preview screen=TemplatePreviewPage');
        context.push('/paywall');
        return;
      }
      // Pro user with entitlement — allow through
    }

    // pushReplacement: removes preview from stack → editor back goes to Home/Templates
    context.pushReplacement('/editor', extra: template.toEditorParams());
  }
}

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}
