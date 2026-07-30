import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:billing/billing.dart';
import '../../data/editor_route_params.dart';
import '../../../templates/data/template_item_model.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Result from the clothing selector — either a blank template or a pre-designed set.
class ClothingSelectorResult {
  /// For blank templates (Pantolon, Gömlek, Tişört)
  final ClothingTemplateType? blankType;

  /// For pre-designed set templates
  final TemplateItemModel? preDesigned;

  const ClothingSelectorResult.blank(ClothingTemplateType type)
      : blankType = type, preDesigned = null;

  const ClothingSelectorResult.designed(TemplateItemModel template)
      : blankType = null, preDesigned = template;
}

/// Classic Clothing template selector — shown as a BOTTOM SHEET / MODAL
/// when the user taps "Create Classic Clothing" on the home screen.
///
/// Fetches templates from Supabase `clothing_templates` table.
/// Returns [ClothingSelectorResult].
class ClassicClothingSelector extends ConsumerStatefulWidget {
  final void Function(ClothingSelectorResult result) onSelect;
  final VoidCallback? onClose;

  const ClassicClothingSelector({
    super.key,
    required this.onSelect,
    this.onClose,
  });

  /// Show this selector as a modal bottom sheet from any context.
  static Future<ClothingSelectorResult?> show(BuildContext context) {
    return showModalBottomSheet<ClothingSelectorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassicClothingSelector(
        onSelect: (result) => Navigator.of(context).pop(result),
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  ConsumerState<ClassicClothingSelector> createState() => _ClassicClothingSelectorState();
}

class _ClassicClothingSelectorState extends ConsumerState<ClassicClothingSelector> {
  List<Map<String, dynamic>> _dbTemplates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
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
          _dbTemplates = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch clothing templates: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleDesignedTemplateTap(Map<String, dynamic> row) {
    final isPro = row['is_pro'] == true;
    if (isPro && !ref.read(canAccessProProvider)) {
      widget.onClose?.call();
      if (mounted) context.push('/paywall');
      return;
    }

    final template = TemplateItemModel(
      templateId: row['id'] as String,
      title: row['name'] as String,
      type: TemplateType.classicClothing,
      clothingTemplate: _resolveClothingType(row['template_type'] as String),
      icon: Icons.checkroom,
      accentColor: const Color(0xFF7C4DFF),
      shirtAssetPath: row['shirt_texture_url'] as String?,
      pantsAssetPath: row['pants_texture_url'] as String?,
      thumbnailAsset: row['shirt_texture_url'] as String?,
      previewAsset: row['preview_front_url'] as String?,
      isPro: isPro,
    );
    widget.onSelect(ClothingSelectorResult.designed(template));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFF8F8FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle bar ──
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header with close button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.clothingSelectorTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.clothingSelectorSubtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.outlineVariant,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),

            const Divider(height: 16),

            // ── Blank Templates Section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(context)!.classicSelectorBlankTemplate,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textHighEmphasis,
                  ),
                ),
              ),
            ),

            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _BlankTemplateChip(
                    label: AppLocalizations.of(context)!.clothingSelectorBlankShirt,
                    subtitle: '585×559',
                    icon: Icons.checkroom,
                    color: const Color(0xFF7C4DFF),
                    onTap: () => widget.onSelect(
                      const ClothingSelectorResult.blank(ClothingTemplateType.blankShirt)),
                  ),
                  SizedBox(width: 8),
                  _BlankTemplateChip(
                    label: AppLocalizations.of(context)!.clothingSelectorBlankPants,
                    subtitle: '585×559',
                    icon: Icons.straighten,
                    color: const Color(0xFF00BCD4),
                    onTap: () => widget.onSelect(
                      const ClothingSelectorResult.blank(ClothingTemplateType.blankPants)),
                  ),
                  const SizedBox(width: 8),
                  _BlankTemplateChip(
                    label: AppLocalizations.of(context)!.clothingSelectorBlankTShirt,
                    subtitle: '128×128',
                    icon: Icons.dry_cleaning,
                    color: const Color(0xFFFF6A1A),
                    onTap: () => widget.onSelect(
                      const ClothingSelectorResult.blank(ClothingTemplateType.blankTShirt)),
                  ),
                ],
              ),
            ),

            const Divider(height: 16),

            // ── Ready-made Sets from Supabase ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(context)!.clothingSelectorReadySets,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textHighEmphasis,
                  ),
                ),
              ),
            ),

            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _dbTemplates.isEmpty
                      ? Center(
                          child: Text(
                            AppLocalizations.of(context)!.clothingSelectorNoTemplates,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.outlineVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: _dbTemplates.length,
                            itemBuilder: (context, index) {
                              final row = _dbTemplates[index];
                              return _SupabaseTemplateCard(
                                row: row,
                                onTap: () => _handleDesignedTemplateTap(row),
                              );
                            },
                          ),
                        ),
            ),

            SizedBox(height: bottomPad > 0 ? bottomPad : 16),
          ],
        ),
      ),
    );
  }

  ClothingTemplateType _resolveClothingType(String dbType) {
    switch (dbType) {
      case 'classic_pants':
        return ClothingTemplateType.blankPants;
      case 'classic_tshirt':
        return ClothingTemplateType.blankTShirt;
      case 'classic_shirt':
      case 'classic_set':
      default:
        return ClothingTemplateType.blankShirt;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// UI COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

class _BlankTemplateChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BlankTemplateChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 110,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
              Text(subtitle, style: TextStyle(fontSize: 9, color: AppColors.outlineVariant, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupabaseTemplateCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  const _SupabaseTemplateCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = row['name'] as String? ?? '';
    final type = row['template_type'] as String? ?? '';
    final previewUrl = row['preview_front_url'] as String?;
    final shirtUrl = row['shirt_texture_url'] as String?;
    final isPro = row['is_pro'] as bool? ?? false;
    // Best image: preview > shirt texture
    final imageUrl = previewUrl ?? shirtUrl;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFFF0F0F3)),
                  if (imageUrl != null)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.checkroom, size: 40, color: AppColors.outlineVariant),
                      ),
                    )
                  else
                    Center(child: Icon(Icons.checkroom, size: 40, color: AppColors.outlineVariant)),
                  if (isPro)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF4444)]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (type.contains('shirt') || type.contains('set'))
                        _miniTag('Shirt', const Color(0xFF7C4DFF)),
                      if (type.contains('pants') || type.contains('set')) ...[
                        const SizedBox(width: 4),
                        _miniTag('Pants', const Color(0xFF00BCD4)),
                      ],
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

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
