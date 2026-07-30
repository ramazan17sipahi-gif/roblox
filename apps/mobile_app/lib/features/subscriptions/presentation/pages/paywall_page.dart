import 'dart:io';
import 'package:billing/billing.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../../l10n/generated/app_localizations.dart';

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  int _selectedPlan = 0;
  bool _isLoading = false;
  List<ProductDetails> _storeProducts = [];
  List<BillingProduct> _billingProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    ref.read(purchaseFlowServiceProvider).startListening();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    try {
      final products = await ref.read(billingRepositoryProvider).getProducts();
      final platformIds = products
          .map((p) => Platform.isIOS ? p.iosProductId : p.androidProductId)
          .whereType<String>()
          .toSet();
      final storeProducts = await ref.read(storeRepositoryProvider).fetchProducts(platformIds);

      if (mounted) {
        setState(() {
          _billingProducts = products;
          _storeProducts = storeProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('[billing] loadProducts error: $e');
    }
  }

  List<BillingProduct> get _subscriptionProducts =>
      _billingProducts.where((p) => p.isSubscription).toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  ProductDetails? _findStoreProduct(BillingProduct bp) {
    final platformId = Platform.isIOS ? bp.iosProductId : bp.androidProductId;
    if (platformId == null) return null;
    try {
      return _storeProducts.firstWhere((s) => s.id == platformId);
    } catch (e) {
      debugPrint('[paywall_page] store product not found: $e');
      return null;
    }
  }

  void _purchase() async {
    final products = _subscriptionProducts;
    if (products.isEmpty || _selectedPlan >= products.length) return;

    final bp = products[_selectedPlan];
    final storeProduct = _findStoreProduct(bp);
    if (storeProduct == null) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(purchaseFlowServiceProvider).subscribe(storeProduct);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _restorePurchases() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(purchaseFlowServiceProvider).restore();
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(entitlementProvider);
    final products = _subscriptionProducts;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (entitlement.isActive && !entitlement.isFree)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entitlement.planCode.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.actionGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20),
                    ],
                  ),
                  child: const Icon(Icons.workspace_premium, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.paywallUnlockPro,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _FeatureRow(text: l10n.paywallFeatureUnlimitedTemplates),
              _FeatureRow(text: l10n.paywallFeatureExport),
              _FeatureRow(text: l10n.paywallFeatureProTemplates),
              _FeatureRow(text: l10n.paywallFeaturePriority),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : products.isEmpty
                        ? Center(
                            child: Text(
                              l10n.paywallNoPlans,
                              style: TextStyle(color: AppColors.outlineVariant),
                            ),
                          )
                        : ListView.builder(
                            itemCount: products.length,
                            itemBuilder: (context, i) {
                              final bp = products[i];
                              final sp = _findStoreProduct(bp);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedPlan = i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _selectedPlan == i
                                            ? AppColors.primary
                                            : AppColors.outlineVariant.withOpacity(0.2),
                                        width: _selectedPlan == i ? 2 : 1,
                                      ),
                                      boxShadow: _selectedPlan == i
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary.withOpacity(0.2),
                                                blurRadius: 12,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    bp.displayName,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(fontWeight: FontWeight.w700),
                                                  ),
                                                  if (bp.planCode == 'studio') ...[
                                                    SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        l10n.paywallBestValue,
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.primary,
                                                          letterSpacing: 1,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                l10n.paywallMonthly,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(color: AppColors.outlineVariant),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          sp?.price ?? '—',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              SizedBox(height: 12),
              GestureDetector(
                onTap: _isLoading ? null : _purchase,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: _isLoading ? null : AppColors.actionGradient,
                    color: _isLoading ? AppColors.surfaceContainerLow : null,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: _isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          )
                        : Text(
                            l10n.paywallSubscribe,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : _restorePurchases,
                child: Text(
                  l10n.paywallRestorePurchases,
                  style: TextStyle(
                    color: AppColors.outlineVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
