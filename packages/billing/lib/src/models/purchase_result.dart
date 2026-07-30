import 'entitlement_state.dart';

class PurchaseResult {
  final String opToken;
  final bool verified;
  final bool granted;
  final bool dedupeHit;
  final int creditsGranted;
  final int walletBalance;
  final EntitlementState? entitlement;

  const PurchaseResult({
    required this.opToken, required this.verified,
    required this.granted, required this.dedupeHit,
    required this.creditsGranted, required this.walletBalance,
    this.entitlement,
  });

  factory PurchaseResult.fromJson(Map<String, dynamic> json) => PurchaseResult(
    opToken: json['opToken'] as String? ?? '',
    verified: json['verified'] as bool? ?? false,
    granted: json['granted'] as bool? ?? false,
    dedupeHit: json['dedupeHit'] as bool? ?? false,
    creditsGranted: json['creditsGranted'] as int? ?? 0,
    walletBalance: (json['wallet'] as Map?)?['balance'] as int? ?? 0,
    entitlement: json['entitlement'] != null
        ? EntitlementState.fromJson(json['entitlement'] as Map<String, dynamic>)
        : null,
  );
}
