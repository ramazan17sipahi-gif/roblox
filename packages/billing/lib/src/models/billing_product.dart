class BillingProduct {
  final String id;
  final String code;
  final String type; // 'subscription' | 'topup'
  final String? planCode;
  final String? iosProductId;
  final String? androidProductId;
  final int creditAmount;
  final String displayName;
  final int displayOrder;
  final bool isActive;

  const BillingProduct({
    required this.id, required this.code, required this.type,
    this.planCode, this.iosProductId, this.androidProductId,
    required this.creditAmount, required this.displayName,
    this.displayOrder = 0, this.isActive = true,
  });

  factory BillingProduct.fromJson(Map<String, dynamic> json) => BillingProduct(
    id: json['id'] as String,
    code: json['code'] as String,
    type: json['type'] as String,
    planCode: json['plan_code'] as String?,
    iosProductId: json['ios_product_id'] as String?,
    androidProductId: json['android_product_id'] as String?,
    creditAmount: json['credit_amount'] as int? ?? 0,
    displayName: json['display_name'] as String,
    displayOrder: json['display_order'] as int? ?? 0,
    isActive: json['is_active'] as bool? ?? true,
  );

  bool get isSubscription => type == 'subscription';
  bool get isTopup => type == 'topup';
}
