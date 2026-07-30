import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/billing_provider.dart';

/// Wraps content that requires Pro/Studio entitlement.
/// Free users see a lock overlay with "Upgrade to Pro" CTA.
class ProGate extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onBlocked;

  const ProGate({super.key, required this.child, this.onBlocked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccess = ref.watch(canAccessProProvider);

    if (canAccess) return child;

    return Stack(
      children: [
        // Blurred/dimmed content
        Opacity(opacity: 0.4, child: IgnorePointer(child: child)),

        // Lock overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              onBlocked?.call();
              context.push('/paywall');
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppColors.actionGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
