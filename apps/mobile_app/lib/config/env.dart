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
