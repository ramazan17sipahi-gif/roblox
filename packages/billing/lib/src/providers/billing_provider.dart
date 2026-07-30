import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet_state.dart';
import '../models/entitlement_state.dart';
import '../models/billing_product.dart';
import '../repositories/billing_repository.dart';

/// Authoritative wallet state from server (cached 5 min to reduce edge calls).
final walletStateProvider = FutureProvider<WalletState>((ref) async {
  final link = ref.keepAlive();
  Future.delayed(const Duration(minutes: 5), link.close);

  final billing = ref.watch(billingRepositoryProvider);
  try {
    return await billing.getWallet();
  } catch (_) {
    return WalletState.empty();
  }
});

/// Derived: current entitlement
final entitlementProvider = Provider<EntitlementState>((ref) {
  final wallet = ref.watch(walletStateProvider);
  return wallet.when(
    data: (w) => w.entitlement,
    loading: () => EntitlementState.free(),
    error: (_, __) => EntitlementState.free(),
  );
});

/// Derived: current balance
final creditBalanceProvider = Provider<int>((ref) {
  final wallet = ref.watch(walletStateProvider);
  return wallet.when(data: (w) => w.balance, loading: () => 0, error: (_, __) => 0);
});

/// Derived: can access pro content
final canAccessProProvider = Provider<bool>((ref) {
  final ent = ref.watch(entitlementProvider);
  return ent.canAccessProContent;
});

/// Billing products catalog
final billingProductsProvider = FutureProvider<List<BillingProduct>>((ref) async {
  final billing = ref.watch(billingRepositoryProvider);
  return billing.getProducts();
});

/// Balance stream (realtime)
final balanceStreamProvider = StreamProvider<int>((ref) {
  final billing = ref.watch(billingRepositoryProvider);
  return billing.streamBalance();
});
