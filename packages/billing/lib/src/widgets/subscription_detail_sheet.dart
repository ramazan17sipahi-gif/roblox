import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/billing_provider.dart';
import '../providers/subscription_sheet_labels_provider.dart';

/// Bottom sheet showing current subscription plan and upgrade/manage actions.
class SubscriptionDetailSheet extends ConsumerWidget {
  const SubscriptionDetailSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletStateProvider);
    final labels = ref.watch(subscriptionSheetLabelsProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            bottomPad + kSubscriptionSheetBottomClearance,
          ),
          child: walletAsync.when(
            loading: () => SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  labels.loadError,
                  style: TextStyle(color: AppColors.outlineVariant),
                ),
              ),
            ),
            data: (wallet) {
              final entitlement = wallet.entitlement;
              final isFree = entitlement.isFree;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      _PlanBadge(planCode: entitlement.planCode),
                      const Spacer(),
                      Icon(
                        isFree ? Icons.lock_outline : Icons.verified,
                        color: isFree ? AppColors.outlineVariant : AppColors.success,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    isFree ? labels.freePlanTitle : labels.activePlanTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFree ? labels.freePlanDesc : entitlement.planCode.toUpperCase(),
                    style: TextStyle(fontSize: 13, color: AppColors.outlineVariant),
                  ),
                  if (entitlement.currentPeriodEnd != null) ...[
                    SizedBox(height: 12),
                    Text(
                      '${labels.renewsOn} ${_formatDate(entitlement.currentPeriodEnd!)}',
                      style: TextStyle(fontSize: 12, color: AppColors.outlineVariant),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SheetButton(
                    label: isFree ? labels.upgradePlan : labels.managePlan,
                    filled: true,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/paywall');
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _SheetButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _SheetButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: filled ? AppColors.actionGradient : null,
          color: filled ? null : Colors.transparent,
          border: filled ? null : Border.all(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String planCode;
  const _PlanBadge({required this.planCode});

  @override
  Widget build(BuildContext context) {
    final color = planCode == 'studio'
        ? const Color(0xFF7C4DFF)
        : planCode == 'pro'
            ? AppColors.primary
            : AppColors.outlineVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        planCode.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
