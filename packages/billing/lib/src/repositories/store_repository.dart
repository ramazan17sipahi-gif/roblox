import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository();
});

/// Platform-agnostic wrapper around in_app_purchase plugin.
/// Handles StoreKit 2 (iOS) and Google Play Billing (Android).
class StoreRepository {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _purchaseController = StreamController<PurchaseDetails>.broadcast();

  /// Stream of individual purchase events
  Stream<PurchaseDetails> get purchaseStream => _purchaseController.stream;

  /// Initialize and start listening to purchase updates
  Future<bool> initialize() async {
    if (kDebugMode) {
      debugPrint('[billing] Store init skipped in debug');
      return false;
    }

    final available = await _iap
        .isAvailable()
        .timeout(const Duration(seconds: 3), onTimeout: () => false);
    if (!available) {
      debugPrint('[billing] Store not available');
      return false;
    }

    _subscription = _iap.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          _purchaseController.add(purchase);
        }
      },
      onDone: () => _purchaseController.close(),
      onError: (e) => debugPrint('[billing] purchaseStream error: $e'),
    );
    return true;
  }

  /// Fetch product details from the store
  Future<List<ProductDetails>> fetchProducts(Set<String> productIds) async {
    if (kDebugMode || productIds.isEmpty) return [];
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint('[billing] queryProductDetails error: ${response.error}');
    }
    return response.productDetails;
  }

  /// Buy a subscription (auto-renewing)
  Future<bool> buySubscription(ProductDetails product, {String? applicationUserName}) async {
    final param = PurchaseParam(productDetails: product, applicationUserName: applicationUserName);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Buy a consumable (top-up credits)
  Future<bool> buyConsumable(ProductDetails product, {String? applicationUserName}) async {
    final param = PurchaseParam(productDetails: product, applicationUserName: applicationUserName);
    return _iap.buyConsumable(purchaseParam: param);
  }

  /// Restore previous purchases
  Future<void> restorePurchases({String? applicationUserName}) async {
    await _iap.restorePurchases(applicationUserName: applicationUserName);
  }

  /// Complete a purchase (required after server verification)
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  /// Get current platform string
  String get currentPlatform => Platform.isIOS ? 'ios' : 'android';

  void dispose() {
    _subscription?.cancel();
    _purchaseController.close();
  }
}
