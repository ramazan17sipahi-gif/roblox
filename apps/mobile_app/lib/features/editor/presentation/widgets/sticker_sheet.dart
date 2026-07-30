import 'dart:ui' as ui;
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'drawing_canvas.dart';

/// Built-in sticker/clipart categories with emoji-based stickers.
/// Phase 2: Will be migrated to real PNG assets when asset pipeline is ready.
class StickerSheet extends StatefulWidget {
  final void Function(CanvasElement element) onStickerSelected;

  /// Active part name for UV-rect-aware spawning (e.g. 'Torso').
  final String? activePartName;

  /// Active part's default face (e.g. 'front', 'back').
  final String? activePartFace;

  /// UV canvas size for center calculation.
  final Size? uvCanvasSize;

  const StickerSheet({
    super.key,
    required this.onStickerSelected,
    this.activePartName,
    this.activePartFace,
    this.uvCanvasSize,
  });

  @override
  State<StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends State<StickerSheet> {
  int _selectedCategory = 0;

  static List<_StickerCategory> _resolvedCategories(AppLocalizations l) => [
    _StickerCategory(l.stickerCategoryGaming, Icons.sports_esports, [
      '🔥', '⚡', '💥', '🎮', '🕹️', '🏆', '🎯', '🚀',
      '💣', '🗡️', '🛡️', '⚔️', '🏹', '🪓', '🔫', '💎',
    ]),
    _StickerCategory(l.stickerCategoryBadges, Icons.verified, [
      '👑', '⭐', '🌟', '💫', '✨', '🏅', '🎖️', '🥇',
      '🥈', '🥉', '🎗️', '💠', '🔷', '🔶', '♦️', '🔴',
    ]),
    _StickerCategory(l.stickerCategorySymbols, Icons.auto_awesome, [
      '❤️', '🖤', '💜', '💙', '💚', '💛', '🧡', '🤍',
      '☠️', '💀', '👻', '🦇', '🐉', '🐍', '🦅', '🦁',
    ]),
    _StickerCategory(l.stickerCategoryNature, Icons.park, [
      '🌹', '🌺', '🌸', '🌻', '🌙', '☀️', '⭐', '🌊',
      '🍀', '🌿', '🍂', '❄️', '🔮', '🌈', '🦋', '🕊️',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final categories = _resolvedCategories(l);
    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.emoji_symbols, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).stickerSheetTitleFull,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, size: 20, color: AppColors.outlineVariant),
                ),
              ],
            ),
          ),
          // Category tabs
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isActive = index == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : const Color(0xFFF0F0F3),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: isActive
                          ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon, size: 14, color: isActive ? Colors.white : AppColors.outlineVariant),
                        SizedBox(width: 4),
                        Text(cat.name, style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : AppColors.onSurface,
                        )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Sticker grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: categories[_selectedCategory].stickers.length,
              itemBuilder: (context, index) {
                final sticker = categories[_selectedCategory].stickers[index];
                return GestureDetector(
                  onTap: () => _onStickerTap(sticker),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.1)),
                    ),
                    child: Center(
                      child: Text(sticker, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  void _onStickerTap(String emoji) {
    final canvasSize = widget.uvCanvasSize ?? const Size(585, 559);
    final partName = widget.activePartName ?? 'unknown';
    final face = widget.activePartFace ?? 'front';

    // Face-aware spawn: place sticker at the UV region center for the active part
    final spawnCenter = _getFaceAwareCenter(canvasSize, partName, face);
    final spawnX = spawnCenter.dx - 24; // center minus half sticker size
    final spawnY = spawnCenter.dy - 24;

    final element = CanvasElement(
      id: 'sticker_${DateTime.now().millisecondsSinceEpoch}',
      text: emoji,
      textStyle: const TextStyle(fontSize: 48),
      position: Offset(spawnX, spawnY),
      scale: 1.0,
      targetPart: partName,
      targetFace: face,
    );

    debugPrint('[sticker-map] elementId=${element.id} part=$partName face=$face '
        'spawnCenter=(${spawnCenter.dx.toStringAsFixed(1)},${spawnCenter.dy.toStringAsFixed(1)}) '
        'canvasSize=${canvasSize.width.toStringAsFixed(0)}x${canvasSize.height.toStringAsFixed(0)}');

    widget.onStickerSelected(element);
    Navigator.pop(context);
  }

  /// Returns the center of the actual UV atlas region for face-aware spawning.
  /// Atlas layout (585×559) from Roblox Classic Clothing UV specification:
  ///   TORSO:     front x=231..361, y=73..203  |  back x=427..557, y=73..203
  ///   RIGHT ARM: front x=217..283, y=349..463 |  back x=85..151, y=349..463
  ///   LEFT ARM:  front x=308..374, y=349..463 |  back x=440..506, y=349..463
  ///   RIGHT LEG: front x=217..283, y=349..463 |  back x=85..151, y=349..463
  ///   LEFT LEG:  front x=308..374, y=349..463 |  back x=440..506, y=349..463
  Offset _getFaceAwareCenter(Size canvas, String? part, String? face) {
    // Atlas region centers (pixel coordinates in 585×559 atlas)
    // These are the REAL UV regions — not guesses.
    // In SET mode (stacked canvas, height > 559), legs are offset by 569
    // because the pants template is below the shirt template.
    final bool isStacked = canvas.height > 559;
    const double pantsYOffset = 569; // 559 (shirt) + 10 (gap)

    switch (part) {
      case 'Torso':
        if (face == 'back') return const Offset(492, 138);  // back: center of (427..557, 73..203)
        return const Offset(296, 138);                       // front: center of (231..361, 73..203)
      case 'Right Arm':
        if (face == 'back') return const Offset(118, 406);   // back: center of (85..151, 349..463)
        return const Offset(250, 406);                       // front: center of (217..283, 349..463)
      case 'Left Arm':
        if (face == 'back') return const Offset(473, 406);   // back: center of (440..506, 349..463)
        return const Offset(341, 406);                       // front: center of (308..374, 349..463)
      case 'Right Leg':
        final double yBase = isStacked ? 406.0 + pantsYOffset : 406.0;
        if (face == 'back') return Offset(118, yBase);
        return Offset(250, yBase);
      case 'Left Leg':
        final double yBase = isStacked ? 406.0 + pantsYOffset : 406.0;
        if (face == 'back') return Offset(473, yBase);
        return Offset(341, yBase);
      case 'Front Decal':
        return Offset(canvas.width / 2, canvas.height / 2);
      default:
        return Offset(canvas.width / 2, canvas.height / 2);
    }
  }
}

class _StickerCategory {
  final String name;
  final IconData icon;
  final List<String> stickers;
  const _StickerCategory(this.name, this.icon, this.stickers);
}
