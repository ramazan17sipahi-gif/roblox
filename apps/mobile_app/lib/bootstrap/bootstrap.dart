import 'package:billing/billing.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../features/ads/data/app_open_ad_service.dart';
import '../features/ads/data/rewarded_ad_service.dart';

/// Initializes core services before the app runs.
class AppBootstrap {
  static final StoreRepository _store = StoreRepository();
  static final RewardedAdService rewardedAds = RewardedAdService();
  static final AppOpenAdService appOpenAds = AppOpenAdService();

  static StoreRepository get store => _store;

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock orientation to portrait initially
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    Env.validate();

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      debug: kDebugMode,
    ).timeout(const Duration(seconds: 12));

    // AdMob / billing: NEVER await during cold start — MobileAds.initialize()
    // can freeze the UI isolate on some devices and leave users on splash.
    // Kick off only after the first frame so SplashPage can navigate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 3), () {
        unawaited(_initAdsSafely());
        unawaited(_initBillingSafely());
      });
    });
  }

  static Future<void> _initAdsSafely() async {
    try {
      await rewardedAds.initialize().timeout(const Duration(seconds: 8),
          onTimeout: () {
        debugPrint('[ads] MobileAds init timed out');
      });
      await appOpenAds.initialize().timeout(const Duration(seconds: 8),
          onTimeout: () {
        debugPrint('[ads] App-open init timed out');
      });
    } catch (e) {
      debugPrint('[ads] bootstrap init failed: $e');
    }
  }

  static Future<void> _initBillingSafely() async {
    // Emülatörde Google Play Store sık crash olur; debug'da billing'e hiç dokunma.
    if (kDebugMode) {
      debugPrint('[billing] Skipped in debug builds (emulator-safe)');
      return;
    }
    try {
      await _store.initialize().timeout(const Duration(seconds: 4),
          onTimeout: () {
        debugPrint('[billing] Store init timed out (emulator?)');
        return false;
      });
    } catch (e) {
      debugPrint('[billing] Store init failed (emulator?): $e');
    }
  }
}
