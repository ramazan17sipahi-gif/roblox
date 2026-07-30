import 'package:billing/billing.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Initializes core services before the app runs.
class AppBootstrap {
  static final StoreRepository _store = StoreRepository();

  static StoreRepository get store => _store;

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Lock orientation to portrait initially
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    Env.validate();

    // Initialize Supabase
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      debug: kDebugMode,
    );

    // Billing: defer + timeout — broken Play Store on emulators can crash/hang startup.
    unawaited(_initBillingSafely());
  }

  static Future<void> _initBillingSafely() async {
    // Emülatörde Google Play Store sık crash olur; debug'da billing'e hiç dokunma.
    if (kDebugMode) {
      debugPrint('[billing] Skipped in debug builds (emulator-safe)');
      return;
    }
    try {
      await _store
          .initialize()
          .timeout(const Duration(seconds: 4), onTimeout: () {
        debugPrint('[billing] Store init timed out (emulator?)');
        return false;
      });
    } catch (e) {
      debugPrint('[billing] Store init failed (emulator?): $e');
    }
  }
}
