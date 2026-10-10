/// Compile-time environment values.
///
/// Secrets are injected at build time via `--dart-define-from-file=env.local.json`
/// so they never live in source control. Copy [env.local.json.example] to
/// `env.local.json` (gitignored) before running or building.
class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment('APP_SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('APP_SUPABASE_ANON_KEY');

  static const String revenueCatPublicKey =
      String.fromEnvironment('APP_REVENUECAT_PUBLIC_KEY');

  /// AdMob publisher (account) ID — NOT an App ID / ad unit ID.
  /// Real ads need App ID (manifest/plist `ca-app-pub-…~…`) + rewarded unit IDs.
  static const String admobPublisherId = String.fromEnvironment(
    'APP_ADMOB_PUBLISHER_ID',
    defaultValue: 'pub-2398858453657345',
  );

  /// Optional production AdMob rewarded unit IDs (`ca-app-pub-…/…`).
  /// When empty, Google's official test rewarded units are used.
  static const String admobRewardedAndroidUnitId = String.fromEnvironment(
    'APP_ADMOB_REWARDED_ANDROID_UNIT_ID',
  );
  static const String admobRewardedIosUnitId = String.fromEnvironment(
    'APP_ADMOB_REWARDED_IOS_UNIT_ID',
  );

  /// Optional production AdMob app-open unit IDs (`ca-app-pub-…/…`).
  /// When empty, Google's official test app-open units are used.
  static const String admobAppOpenAndroidUnitId = String.fromEnvironment(
    'APP_ADMOB_APP_OPEN_ANDROID_UNIT_ID',
  );
  static const String admobAppOpenIosUnitId = String.fromEnvironment(
    'APP_ADMOB_APP_OPEN_IOS_UNIT_ID',
  );

  /// Optional production AdMob App IDs (`ca-app-pub-…~…`) for docs/build notes.
  /// Native AndroidManifest / Info.plist must be updated to match before release.
  static const String admobAndroidAppId = String.fromEnvironment(
    'APP_ADMOB_ANDROID_APP_ID',
  );
  static const String admobIosAppId = String.fromEnvironment(
    'APP_ADMOB_IOS_APP_ID',
  );

  static const String environment = String.fromEnvironment(
    'APP_ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isDevelopment => environment == 'development';

  static bool get isProduction => environment == 'production';

  /// Fails fast when secrets were not injected at compile time.
  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration. Copy env.local.json.example to '
        'env.local.json, fill in your values, then run/build with '
        '--dart-define-from-file=env.local.json',
      );
    }
  }
}
