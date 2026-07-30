class EntitlementState {
  final String planCode;
  final String status;
  final DateTime? currentPeriodEnd;
  final bool autoRenew;
  final String? platform;
  final String? productCode;

  const EntitlementState({
    required this.planCode, required this.status,
    this.currentPeriodEnd, this.autoRenew = false,
    this.platform, this.productCode,
  });

  factory EntitlementState.free() => const EntitlementState(planCode: 'free', status: 'active');

  factory EntitlementState.fromJson(Map<String, dynamic> json) => EntitlementState(
    planCode: json['planCode'] as String? ?? 'free',
    status: json['status'] as String? ?? 'active',
    currentPeriodEnd: json['currentPeriodEnd'] != null ? DateTime.tryParse(json['currentPeriodEnd'] as String) : null,
    autoRenew: json['autoRenew'] as bool? ?? false,
    platform: json['platform'] as String?,
    productCode: json['productCode'] as String?,
  );

  bool get isFree => planCode == 'free';
  bool get isPro => planCode == 'pro' || planCode == 'studio';
  bool get isStudio => planCode == 'studio';
  bool get isActive => status == 'active' || status == 'grace_period';

  /// Can user access is_pro content?
  bool get canAccessProContent => isActive && isPro;
}
