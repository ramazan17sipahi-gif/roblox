import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_config.dart';
import 'full_screen_ad_coordinator.dart';

/// Loads and shows AdMob rewarded ads (one at a time, preloads next).
class RewardedAdService {
  RewardedAd? _ad;
  bool _loading = false;
  bool _initialized = false;

  bool get isReady => _ad != null;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      debugPrint(
          '[ads] MobileAds initialized unit=${AdMobConfig.rewardedUnitId}');
      unawaited(preload());
    } catch (e) {
      debugPrint('[ads] MobileAds init failed: $e');
    }
  }

  Future<void> preload() async {
    if (!_initialized || _loading || _ad != null) return;
    _loading = true;
    final completer = Completer<void>();

    await RewardedAd.load(
      adUnitId: AdMobConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          debugPrint('[ads] rewarded loaded');
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _loading = false;
          debugPrint('[ads] rewarded failed to load: $error');
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    await completer.future;
  }

  /// Shows a rewarded ad. Returns `true` only if the user earned the reward.
  Future<bool> showRewarded() async {
    await initialize();
    if (_ad == null) {
      await preload();
    }
    final ad = _ad;
    if (ad == null || !FullScreenAdCoordinator.tryBegin()) return false;

    final completer = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        FullScreenAdCoordinator.end();
        unawaited(preload());
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[ads] rewarded failed to show: $error');
        ad.dispose();
        _ad = null;
        FullScreenAdCoordinator.end();
        unawaited(preload());
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      ad.show(
        onUserEarnedReward: (_, reward) {
          earned = true;
          debugPrint(
              '[ads] reward earned type=${reward.type} amount=${reward.amount}');
        },
      );
    } catch (e) {
      FullScreenAdCoordinator.end();
      ad.dispose();
      _ad = null;
      unawaited(preload());
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
