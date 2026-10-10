import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/billing_provider.dart';
import 'subscription_detail_sheet.dart';

/// Compact subscription status chip shown in the app header.
class SubscriptionPill extends ConsumerWidget {
  const SubscriptionPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletStateProvider);

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final height = MediaQuery.of(ctx).size.height;
          return Padding(
            padding: EdgeInsets.only(top: height * 0.25),
            child: const SubscriptionDetailSheet(),
          );
        },
      ),
      child: walletAsync.when(
        loading: () => _buildChip(
          label: '…',
          color: AppColors.outlineVariant,
          filled: false,
        ),
        error: (_, __) => _buildChip(
          label: 'PRO',
          color: AppColors.primary,
          filled: false,
        ),
        data: (wallet) {
          final plan = wallet.entitlement.planCode;
          if (wallet.entitlement.isFree) {
            return _buildChip(
              label: 'PRO',
              color: AppColors.primary,
              filled: false,
              icon: Icons.workspace_premium,
            );
          }
          return _buildChip(
            label: plan.toUpperCase(),
            color: plan == 'studio'
                ? const Color(0xFF7C4DFF)
                : AppColors.primary,
            filled: true,
          );
        },
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required Color color,
    required bool filled,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: filled ? 0.35 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
