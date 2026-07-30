import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:networking/networking.dart';
import '../models/wallet_state.dart';
import '../models/purchase_result.dart';
import '../models/billing_product.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return BillingRepository(supabase);
});

/// Server-side billing API calls via Supabase Edge Functions.
class BillingRepository {
  final SupabaseClient _supabase;
  BillingRepository(this._supabase);

  /// Expose current user ID for purchase flows
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// POST /billing/verify-purchase
  Future<PurchaseResult> verifyPurchase({
    required String platform,
    required String productId,
    String? purchaseToken,
    String? transactionId,
    String? receiptData,
  }) async {
    final res = await _supabase.functions.invoke('verify-purchase', body: {
      'platform': platform,
      'productId': productId,
      if (purchaseToken != null) 'purchaseToken': purchaseToken,
      if (transactionId != null) 'transactionId': transactionId,
      if (receiptData != null) 'receiptData': receiptData,
    });
    if (res.status != 200) throw Exception('verify-purchase failed: ${res.status}');
    return PurchaseResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /billing/restore
  Future<PurchaseResult> restorePurchases({
    required String platform,
    required List<Map<String, String>> receipts,
  }) async {
    final res = await _supabase.functions.invoke('restore-purchases', body: {
      'platform': platform,
      'receipts': receipts,
    });
    if (res.status != 200) throw Exception('restore failed: ${res.status}');
    return PurchaseResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /billing/wallet
  Future<WalletState> getWallet() async {
    final res = await _supabase.functions.invoke('get-wallet', method: HttpMethod.get);
    if (res.status != 200) throw Exception('get-wallet failed: ${res.status}');
    return WalletState.fromJson(res.data as Map<String, dynamic>);
  }

  /// Fetch active subscription products from Supabase catalog.
  Future<List<BillingProduct>> getProducts() async {
    final res = await _supabase
        .from('billing_products')
        .select()
        .eq('is_active', true)
        .eq('type', 'subscription')
        .order('display_order');
    return (res as List).map((e) => BillingProduct.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Stream wallet balance via credit_wallets realtime
  Stream<int> streamBalance() async* {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) { yield 0; return; }

    // Initial fetch
    final initial = await _supabase.from('credit_wallets').select('balance').eq('user_id', userId).maybeSingle();
    yield (initial?['balance'] as int?) ?? 0;

    // Realtime updates
    await for (final _ in _supabase.from('credit_wallets').stream(primaryKey: ['user_id']).eq('user_id', userId)) {
      final row = await _supabase.from('credit_wallets').select('balance').eq('user_id', userId).maybeSingle();
      yield (row?['balance'] as int?) ?? 0;
    }
  }
}
