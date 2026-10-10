import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admob_config.dart';

/// Persists per-template rewarded-ad progress and unlocks for Pro skins.
class ProSkinUnlockStore {
  ProSkinUnlockStore(this._prefs);

  final SharedPreferences _prefs;

  static const _unlockedKey = 'pro_skin_unlocked_ids';
  static String _progressKey(String templateId) => 'pro_skin_ads_$templateId';

  Set<String> get unlockedIds {
    final raw = _prefs.getString(_unlockedKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.toSet();
    } catch (e) {
      debugPrint('[pro_skin_unlock] parse unlocked failed: $e');
      return {};
    }
  }

  bool isUnlocked(String templateId) => unlockedIds.contains(templateId);

  int watchedCount(String templateId) {
    if (isUnlocked(templateId)) {
      return AdMobConfig.requiredRewardedAdsForProSkin;
    }
    return _prefs.getInt(_progressKey(templateId)) ?? 0;
  }

  int remainingAds(String templateId) {
    final left = AdMobConfig.requiredRewardedAdsForProSkin - watchedCount(templateId);
    return left.clamp(0, AdMobConfig.requiredRewardedAdsForProSkin);
  }

  /// Records one completed rewarded ad. Returns `true` when the skin unlocks.
  Future<bool> recordRewardedAd(String templateId) async {
    if (isUnlocked(templateId)) return true;

    final next = (watchedCount(templateId) + 1)
        .clamp(0, AdMobConfig.requiredRewardedAdsForProSkin);
    await _prefs.setInt(_progressKey(templateId), next);

    if (next >= AdMobConfig.requiredRewardedAdsForProSkin) {
      await _markUnlocked(templateId);
      return true;
    }
    return false;
  }

  Future<void> _markUnlocked(String templateId) async {
    final ids = unlockedIds..add(templateId);
    await _prefs.setString(_unlockedKey, jsonEncode(ids.toList()));
    await _prefs.setInt(
      _progressKey(templateId),
      AdMobConfig.requiredRewardedAdsForProSkin,
    );
    debugPrint('[pro_skin_unlock] unlocked templateId=$templateId');
  }
}
