import 'package:billing/billing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../templates/data/access_tier.dart';
import '../ads_providers.dart';
import '../presentation/widgets/pro_only_unlock_sheet.dart';
import '../presentation/widgets/pro_skin_unlock_sheet.dart';

/// Central catalog unlock rules for Ad vs Pro ranks.
class SkinAccessGate {
  static bool isUnlocked({
    required AccessTier tier,
    required bool canAccessPro,
    required bool adUnlocked,
  }) {
    if (tier == AccessTier.free) return true;
    if (canAccessPro) return true;
    if (tier == AccessTier.ad && adUnlocked) return true;
    return false;
  }

  /// Returns true when the user may enter the editor with this skin.
  static Future<bool> ensureUnlocked({
    required BuildContext context,
    required WidgetRef ref,
    required AccessTier tier,
    required String templateId,
    required String templateTitle,
  }) async {
    if (tier == AccessTier.free) return true;
    if (ref.read(canAccessProProvider)) return true;

    if (tier == AccessTier.ad) {
      if (ref.read(isProSkinUnlockedProvider(templateId))) return true;
      final unlocked = await ProSkinUnlockSheet.show(
        context,
        templateId: templateId,
        templateTitle: templateTitle,
      );
      if (unlocked) {
        ref.invalidate(isProSkinUnlockedProvider(templateId));
      }
      return unlocked;
    }

    await ProOnlyUnlockSheet.show(
      context,
      templateTitle: templateTitle,
    );
    return ref.read(canAccessProProvider);
  }
}
