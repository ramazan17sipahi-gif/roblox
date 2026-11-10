import 'dart:async';
import 'dart:io';
import 'package:billing/billing.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/legal_links.dart';

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

/// What the paywall shows after the user leaves Apple's purchase sheet.
enum _PurchasePhase { idle, verifying, success, failed }

class _PaywallPageState extends ConsumerState<PaywallPage> {
  _PurchasePhase _phase = _PurchasePhase.idle;
  DateTime? _renewsOn;
  int _selectedPlan = 0;
  bool _isLoading = false;
  List<ProductDetails> _storeProducts = [];
  List<BillingProduct> _billingProducts = [];
  StreamSubscription<PurchaseDetails>? _purchaseSub;
  String? _pendingProductId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    // Purchase verification runs app-wide (PurchaseFlowService, started at app
    // launch). The paywall only listens to update its own loading/close state.
    _purchaseSub = ref.read(storeRepositoryProvider).purchaseStream.listen(_onPurchaseUpdate);
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  void _onPurchaseUpdate(PurchaseDetails purchase) {
    if (!mounted || _pendingProductId == null) return;
    if (purchase.productID != _pendingProductId) return;
    if (purchase.status == PurchaseStatus.pending) return;

    _pendingProductId = null;
    setState(() => _isLoading = false);

    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      // Apple took the payment. Stay on this screen and show the result of
      // our server verification instead of closing silently.
      _confirmEntitlement();
    } else if (purchase.status == PurchaseStatus.error) {
      _showError(purchase.error?.message ?? AppLocalizations.of(context)!.paywallNoPlans);
    }
    // PurchaseStatus.canceled: user closed the Apple sheet, just re-enable the button.
  }

  /// Server verification runs in PurchaseFlowService. Poll the wallet until
  /// the Pro entitlement shows up, then show success; otherwise show failure.
  Future<void> _confirmEntitlement() async {
    if (!mounted) return;
    setState(() => _phase = _PurchasePhase.verifying);
    for (var attempt = 0; attempt < 10; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      ref.invalidate(walletStateProvider);
      final wallet = await ref.read(walletStateProvider.future);
      if (!mounted) return;
      if (wallet.entitlement.canAccessProContent) {
        setState(() {
          _renewsOn = wallet.entitlement.currentPeriodEnd;
          _phase = _PurchasePhase.success;
        });
        return;
      }
    }
    if (mounted) setState(() => _phase = _PurchasePhase.failed);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
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

  /// Only plans that the store actually returned are shown and purchasable.
  /// A plan without a store product would render a dead "Subscribe" button.
  List<BillingProduct> get _subscriptionProducts =>
      _billingProducts
          .where((p) => p.isSubscription && _findStoreProduct(p) != null)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  ProductDetails? _findStoreProduct(BillingProduct bp) {
    final platformId = Platform.isIOS ? bp.iosProductId : bp.androidProductId;
    if (platformId == null) return null;
    for (final s in _storeProducts) {
      if (s.id == platformId) return s;
    }
    return null;
  }

  void _purchase() async {
    final l10n = AppLocalizations.of(context)!;
    final products = _subscriptionProducts;
    if (products.isEmpty || _selectedPlan >= products.length) {
      debugPrint('[paywall_page] no purchasable store product; store returned ${_storeProducts.map((p) => p.id).toList()}');
      _showError(l10n.paywallNoPlans);
      return;
    }

    final bp = products[_selectedPlan];
    final storeProduct = _findStoreProduct(bp)!;

    setState(() => _isLoading = true);
    _pendingProductId = storeProduct.id;

    try {
      final started = await ref.read(purchaseFlowServiceProvider).subscribe(storeProduct);
      if (!started && mounted) {
        _pendingProductId = null;
        setState(() => _isLoading = false);
        _showError(l10n.paywallNoPlans);
      }
    } catch (e) {
      _pendingProductId = null;
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e.toString());
      }
    }
  }

  void _restorePurchases() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(purchaseFlowServiceProvider).restore();
      if (!mounted) return;
      setState(() => _isLoading = false);
      // Restored transactions are verified by PurchaseFlowService; show the
      // outcome here so the user knows whether Pro is active.
      await _confirmEntitlement();
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

    if (_phase != _PurchasePhase.idle) {
      return _buildResult(context, l10n);
    }

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
              _FeatureRow(text: l10n.paywallFeatureProTemplates),
              _FeatureRow(text: l10n.paywallFeatureNoAds),
              _FeatureRow(text: l10n.paywallFeatureExport),
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
                                              Text(
                                                bp.displayName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(fontWeight: FontWeight.w700),
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
              // Required by App Store Guideline 3.1.2: functional links to
              // Terms of Use (EULA) and Privacy Policy inside the purchase flow.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => openLegalDocument(context, LegalDocument.terms),
                    child: Text(
                      l10n.settingsTermsOfService,
                      style: TextStyle(color: AppColors.outlineVariant, fontSize: 12),
                    ),
                  ),
                  Text('·', style: TextStyle(color: AppColors.outlineVariant)),
                  TextButton(
                    onPressed: () => openLegalDocument(context, LegalDocument.privacy),
                    child: Text(
                      l10n.settingsPrivacyPolicy,
                      style: TextStyle(color: AppColors.outlineVariant, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _PaywallResult on _PaywallPageState {
  Widget _buildResult(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    late final Widget mark;
    late final String title;
    late final String body;
    String? meta;
    final actions = <Widget>[];

    switch (_phase) {
      case _PurchasePhase.verifying:
        mark = const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
        );
        title = l10n.paywallVerifyingTitle;
        body = l10n.paywallVerifyingDesc;
        break;
      case _PurchasePhase.success:
        mark = const Icon(Icons.check_circle, size: 56, color: AppColors.success);
        title = l10n.paywallSuccessTitle;
        body = l10n.paywallSuccessDesc;
        if (_renewsOn != null) {
          meta = '${l10n.subscriptionSheetRenewsOn} ${MaterialLocalizations.of(context).formatMediumDate(_renewsOn!.toLocal())}';
        }
        actions.add(_resultButton(
          label: l10n.commonDone,
          filled: true,
          onTap: () => Navigator.of(context).maybePop(),
        ));
        break;
      case _PurchasePhase.failed:
      case _PurchasePhase.idle:
        mark = const Icon(Icons.error_outline, size: 56, color: AppColors.error);
        title = l10n.paywallFailedTitle;
        body = l10n.paywallFailedDesc;
        actions
          ..add(_resultButton(
            label: l10n.paywallRestorePurchases,
            filled: true,
            onTap: _restorePurchases,
          ))
          ..add(const SizedBox(height: 12))
          ..add(_resultButton(
            label: l10n.commonClose,
            filled: false,
            onTap: () => Navigator.of(context).maybePop(),
          ));
        break;
    }

    return PopScope(
      canPop: _phase != _PurchasePhase.verifying,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(child: mark),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.outlineVariant),
                ),
                if (meta != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    meta,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
                const Spacer(),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultButton({required String label, required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: filled ? null : Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
        ),
        child: Center(
          child: _isLoading && filled
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: filled ? Colors.white : AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
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
