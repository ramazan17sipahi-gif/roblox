import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../ads_providers.dart';
import '../../data/admob_config.dart';

/// Modal shown when a free user taps a Pro skin.
/// Options: watch 2 rewarded ads, or open the Pro paywall.
class ProSkinUnlockSheet extends ConsumerStatefulWidget {
  final String templateId;
  final String templateTitle;

  const ProSkinUnlockSheet({
    super.key,
    required this.templateId,
    required this.templateTitle,
  });

  /// Returns `true` if the skin was unlocked (ads completed or already unlocked).
  static Future<bool> show(
    BuildContext context, {
    required String templateId,
    required String templateTitle,
  }) async {
    final unlocked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProSkinUnlockSheet(
        templateId: templateId,
        templateTitle: templateTitle,
      ),
    );
    return unlocked == true;
  }

  @override
  ConsumerState<ProSkinUnlockSheet> createState() => _ProSkinUnlockSheetState();
}

class _ProSkinUnlockSheetState extends ConsumerState<ProSkinUnlockSheet> {
  bool _busy = false;
  int _watched = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProgress());
    ref.read(rewardedAdServiceProvider).initialize();
  }

  Future<void> _refreshProgress() async {
    final store = await ref.read(proSkinUnlockStoreProvider.future);
    if (!mounted) return;
    setState(() => _watched = store.watchedCount(widget.templateId));
    if (store.isUnlocked(widget.templateId)) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _watchAd() async {
    if (_busy) return;
    setState(() => _busy = true);

    final l = AppLocalizations.of(context);
    final ads = ref.read(rewardedAdServiceProvider);
    final earned = await ads.showRewarded();

    if (!mounted) return;

    if (!earned) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.proSkinAdsFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final store = await ref.read(proSkinUnlockStoreProvider.future);
    final unlocked = await store.recordRewardedAd(widget.templateId);
    ref.invalidate(isProSkinUnlockedProvider(widget.templateId));
    ref.invalidate(proSkinUnlockStoreProvider);

    if (!mounted) return;

    setState(() {
      _watched = store.watchedCount(widget.templateId);
      _busy = false;
    });

    if (unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.proSkinUnlocked),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l.proSkinAdsProgress(_watched, AdMobConfig.requiredRewardedAdsForProSkin),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _goPro() {
    Navigator.of(context).pop(false);
    context.push('/paywall');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final required = AdMobConfig.requiredRewardedAdsForProSkin;
    final remaining = (required - _watched).clamp(0, required);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF4444)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.proSkinUnlockTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      widget.templateTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.outlineVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l.proSkinUnlockSubtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 16),
          // Progress
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.ondemand_video, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.proSkinAdsProgress(_watched, required),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Text(
                  '$_watched/$required',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: required == 0 ? 0 : _watched / required,
              minHeight: 6,
              backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.15),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          DSButton(
            label: _busy
                ? l.proSkinAdsLoading
                : l.proSkinWatchAds(_watched, required),
            icon: Icons.play_circle_outline,
            isLoading: _busy,
            onPressed: _busy || remaining <= 0 ? null : _watchAd,
          ),
          const SizedBox(height: 10),
          DSButton(
            label: l.proSkinGetPro,
            icon: Icons.workspace_premium,
            variant: DSButtonVariant.outline,
            onPressed: _busy ? null : _goPro,
          ),
        ],
      ),
    );
  }
}
