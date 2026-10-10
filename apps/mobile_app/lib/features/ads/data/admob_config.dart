import 'dart:io';

import '../../../config/env.dart';

/// AdMob unit IDs.
///
/// Account publisher: [Env.admobPublisherId] (`pub-2398858453657345`).
/// That alone is not enough — create an App + Rewarded unit in AdMob, then set:
/// - AndroidManifest / Info.plist App ID (`ca-app-pub-…~…`)
/// - [Env.admobRewardedAndroidUnitId] / [Env.admobRewardedIosUnitId] (`ca-app-pub-…/…`)
///
/// Until those are set, Google's official test rewarded units are used.
class AdMobConfig {
  AdMobConfig._();

  /// How many rewarded ads a free user must finish to unlock one Pro skin.
  static const int requiredRewardedAdsForProSkin = 2;

  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';
  static const _testAppOpenAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const _testAppOpenIos = 'ca-app-pub-3940256099942544/5575463023';

  static String get publisherId => Env.admobPublisherId;

  static bool get hasProductionRewardedUnit {
    if (Platform.isIOS) return Env.admobRewardedIosUnitId.isNotEmpty;
    return Env.admobRewardedAndroidUnitId.isNotEmpty;
  }

  static String get rewardedUnitId {
    if (Platform.isIOS) {
      const configured = Env.admobRewardedIosUnitId;
      if (configured.isNotEmpty) return configured;
      return _testRewardedIos;
    }
    const configured = Env.admobRewardedAndroidUnitId;
    if (configured.isNotEmpty) return configured;
    return _testRewardedAndroid;
  }

  static bool get hasProductionAppOpenUnit {
    if (Platform.isIOS) return Env.admobAppOpenIosUnitId.isNotEmpty;
    return Env.admobAppOpenAndroidUnitId.isNotEmpty;
  }

  static String get appOpenUnitId {
    if (Platform.isIOS) {
      const configured = Env.admobAppOpenIosUnitId;
      if (configured.isNotEmpty) return configured;
      return _testAppOpenIos;
    }
    const configured = Env.admobAppOpenAndroidUnitId;
    if (configured.isNotEmpty) return configured;
    return _testAppOpenAndroid;
  }
}
