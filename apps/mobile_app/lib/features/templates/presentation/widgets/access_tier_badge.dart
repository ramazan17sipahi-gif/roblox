import 'package:flutter/material.dart';

import '../../data/access_tier.dart';

/// Compact AD / PRO chip for catalog cards and preview heroes.
class AccessTierBadge extends StatelessWidget {
  final AccessTier tier;
  final AccessTierBadgeSize size;

  const AccessTierBadge({
    super.key,
    required this.tier,
    this.size = AccessTierBadgeSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (!tier.isGated) return const SizedBox.shrink();

    final isPro = tier == AccessTier.pro;
    final compact = size == AccessTierBadgeSize.compact;
    final colors = isPro
        ? const [Color(0xFFFF793A), Color(0xFF9F3B00)]
        : const [Color(0xFF00B4D8), Color(0xFF0077B6)];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(compact ? 6 : 10),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPro ? Icons.workspace_premium : Icons.play_circle_fill,
            color: Colors.white,
            size: compact ? 10 : 14,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            isPro ? 'PRO' : 'AD',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

enum AccessTierBadgeSize { compact, large }
