/// Catalog access rank for clothing templates and stickers.
enum AccessTier {
  /// Open to everyone.
  free,

  /// Unlock by watching rewarded ads, or with a Pro/Studio subscription.
  ad,

  /// Subscription only — ads cannot unlock this item.
  pro;

  static AccessTier fromString(String? value) {
    switch (value) {
      case 'ad':
        return AccessTier.ad;
      case 'pro':
        return AccessTier.pro;
      default:
        return AccessTier.free;
    }
  }

  /// Reads `access_tier`, falling back to legacy `is_pro` → [AccessTier.ad].
  static AccessTier fromRow(Map<String, dynamic> row) {
    final raw = row['access_tier'] as String?;
    if (raw == 'ad' || raw == 'pro' || raw == 'free') {
      return fromString(raw);
    }
    return row['is_pro'] == true ? AccessTier.ad : AccessTier.free;
  }

  bool get isGated => this != AccessTier.free;
  bool get canUnlockWithAds => this == AccessTier.ad;
  bool get requiresSubscription => this == AccessTier.pro;
}
