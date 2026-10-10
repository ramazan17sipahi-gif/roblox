import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_config.dart';
import 'full_screen_ad_coordinator.dart';

/// Preloads and displays app-open ads for eligible free users.
class AppOpenAdService {
  static const _maximumAdAge = Duration(hours: 4);
  static const _minimumInterval = Duration(minutes: 10);

  AppOpenAd? _ad;
  DateTime? _loadedAt;
  DateTime? _lastShownAt;
  bool _loading = false;
  bool _initialized = false;
  bool _showing = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      debugPrint(
          '[ads] App-open initialized unit=${AdMobConfig.appOpenUnitId}');
      unawaited(preload());
    } catch (e) {
      debugPrint('[ads] App-open init failed: $e');
    }
  }

  Future<void> preload() async {
    if (!_initialized || _loading || _ad != null) return;
    _loading = true;
    final completer = Completer<void>();

    await AppOpenAd.load(
      adUnitId: AdMobConfig.appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loadedAt = DateTime.now();
          _loading = false;
          debugPrint('[ads] app-open loaded');
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _loadedAt = null;
          _loading = false;
          debugPrint('[ads] app-open failed to load: $error');
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    await completer.future;
  }

  Future<bool> showIfAvailable() async {
    if (_showing) return false;

    final lastShownAt = _lastShownAt;
    if (lastShownAt != null &&
        DateTime.now().difference(lastShownAt) < _minimumInterval) {
      return false;
    }

    await initialize();
    _disposeIfExpired();
    if (_ad == null) await preload();

    final ad = _ad;
    if (ad == null || !FullScreenAdCoordinator.tryBegin()) return false;

    _ad = null;
    _loadedAt = null;
    _showing = true;
    _lastShownAt = DateTime.now();
    final completer = Completer<bool>();

    void finish(bool shown) {
      _showing = false;
      FullScreenAdCoordinator.end();
      unawaited(preload());
      if (!completer.isCompleted) completer.complete(shown);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        finish(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[ads] app-open failed to show: $error');
        ad.dispose();
        finish(false);
      },
    );

    try {
      ad.show();
    } catch (e) {
      debugPrint('[ads] app-open show threw: $e');
      ad.dispose();
      finish(false);
    }
    return completer.future;
  }

  void _disposeIfExpired() {
    final loadedAt = _loadedAt;
    if (loadedAt == null ||
        DateTime.now().difference(loadedAt) <= _maximumAdAge) {
      return;
    }
    _ad?.dispose();
    _ad = null;
    _loadedAt = null;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
    _loadedAt = null;
  }
}
