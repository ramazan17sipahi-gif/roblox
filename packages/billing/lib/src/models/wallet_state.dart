import 'entitlement_state.dart';

class LedgerEntry {
  final String id;
  final int delta;
  final String reason;
  final String? status;
  final DateTime createdAt;

  const LedgerEntry({required this.id, required this.delta, required this.reason, this.status, required this.createdAt});

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    id: json['id'] as String, delta: json['delta'] as int,
    reason: json['reason'] as String, status: json['status'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class WalletState {
  final int balance;
  final EntitlementState entitlement;
  final List<LedgerEntry> recentLedger;

  const WalletState({required this.balance, required this.entitlement, this.recentLedger = const []});

  factory WalletState.empty() => WalletState(balance: 0, entitlement: EntitlementState.free());

  factory WalletState.fromJson(Map<String, dynamic> json) => WalletState(
    balance: json['balance'] as int? ?? 0,
    entitlement: EntitlementState.fromJson(json['entitlement'] as Map<String, dynamic>? ?? {}),
    recentLedger: (json['recentLedger'] as List?)?.map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );

  /// Credit pill threshold states
  bool get isNormal => balance >= 20;
  bool get isLow => balance >= 5 && balance < 20;
  bool get isCritical => balance < 5;
}
