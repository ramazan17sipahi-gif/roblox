import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../repositories/billing_repository.dart';
import '../repositories/store_repository.dart';
import '../models/purchase_result.dart';
import '../providers/billing_provider.dart';

final purchaseFlowServiceProvider = Provider<PurchaseFlowService>((ref) {
  return PurchaseFlowService(
    billing: ref.watch(billingRepositoryProvider),
    store: ref.watch(storeRepositoryProvider),
    ref: ref,
  );
});

/// Orchestrates: buy → verify → update UI
class PurchaseFlowService {
  final BillingRepository billing;
  final StoreRepository store;
  final Ref ref;
  StreamSubscription<PurchaseDetails>? _sub;

  PurchaseFlowService({required this.billing, required this.store, required this.ref});

  /// Start listening to purchase completions
  void startListening() {
    _sub = store.purchaseStream.listen(_handlePurchase);
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    debugPrint('[billing] purchase status=${purchase.status} product=${purchase.productID}');

    if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
      try {
        // Server-side verify
        final result = await billing.verifyPurchase(
          platform: store.currentPlatform,
          productId: purchase.productID,
          purchaseToken: purchase.verificationData.serverVerificationData,
          transactionId: purchase.purchaseID,
        );

        debugPrint('[billing] verified=${result.verified} granted=${result.granted} credits=${result.creditsGranted}');

        // Complete the purchase with the store
        await store.completePurchase(purchase);

        // Refresh wallet state
        ref.invalidate(walletStateProvider);
      } catch (e) {
        debugPrint('[billing] verification failed: $e');
        // Still complete to avoid re-delivery loops
        await store.completePurchase(purchase);
      }
    } else if (purchase.status == PurchaseStatus.error) {
      debugPrint('[billing] purchase error: ${purchase.error}');
      await store.completePurchase(purchase);
    } else if (purchase.status == PurchaseStatus.pending) {
      debugPrint('[billing] purchase pending (offline/deferred)');
    }
  }

  /// Initiate a subscription purchase
  Future<bool> subscribe(ProductDetails product) async {
    final userId = billing.currentUserId;
    return store.buySubscription(product, applicationUserName: userId);
  }

  /// Initiate a top-up purchase
  Future<bool> buyTopup(ProductDetails product) async {
    final userId = billing.currentUserId;
    return store.buyConsumable(product, applicationUserName: userId);
  }

  /// Restore purchases
  Future<void> restore() async {
    final userId = billing.currentUserId;
    await store.restorePurchases(applicationUserName: userId);
  }

  void dispose() {
    _sub?.cancel();
  }
}
