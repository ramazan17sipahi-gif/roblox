/// App-wide constants for URLs and branding.
class AppConfig {
  AppConfig._();

  static const appName = 'RBLX Clothing Maker: Shirts & Pants';
  static const appNameShort = 'RBLX Clothing Maker';
  static const appTagline = 'Shirts & Pants';

  static const logoAsset = 'assets/branding/app_logo.png';
  static const logoHeroAsset = 'assets/branding/app_logo_hero.png';

  /// Public legal & help pages on hun.social.
  static const helpUrl = 'https://hun.social';
  static const privacyUrl = 'https://hun.social/privacy';
  static const termsUrl = 'https://hun.social/terms';

  static const supportEmail = 'support@hun.social';

  /// Public website base (share links, legal pages).
  static const webBaseUrl = 'https://hun.social';

  static String designShareUrl(String designId) => '$webBaseUrl/design/$designId';

  /// Roblox OAuth redirect registered in Creator Dashboard + app deep link.
  static const robloxOAuthRedirectUri = 'com.rblxclothingmaker.app://roblox-oauth-callback';
  static const robloxOAuthCallbackScheme = 'com.rblxclothingmaker.app';
}
