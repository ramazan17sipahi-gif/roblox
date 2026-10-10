import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../bootstrap/bootstrap.dart';
import 'data/app_open_ad_service.dart';
import 'data/pro_skin_unlock_store.dart';
import 'data/rewarded_ad_service.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final proSkinUnlockStoreProvider =
    FutureProvider<ProSkinUnlockStore>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return ProSkinUnlockStore(prefs);
});

/// Shared singleton initialized in [AppBootstrap] so preload survives navigation.
final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) {
  return AppBootstrap.rewardedAds;
});

final appOpenAdServiceProvider = Provider<AppOpenAdService>((ref) {
  return AppBootstrap.appOpenAds;
});

/// Synchronous unlock check once the store is ready; false while loading.
final isProSkinUnlockedProvider =
    Provider.family<bool, String>((ref, templateId) {
  final store = ref.watch(proSkinUnlockStoreProvider).valueOrNull;
  return store?.isUnlocked(templateId) ?? false;
});
