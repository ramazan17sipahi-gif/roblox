/// Localized labels for [SubscriptionDetailSheet].
class SubscriptionSheetLabels {
  final String renewsOn;
  final String upgradePlan;
  final String managePlan;
  final String loadError;
  final String freePlanTitle;
  final String freePlanDesc;
  final String activePlanTitle;

  const SubscriptionSheetLabels({
    required this.renewsOn,
    required this.upgradePlan,
    required this.managePlan,
    required this.loadError,
    required this.freePlanTitle,
    required this.freePlanDesc,
    required this.activePlanTitle,
  });

  static const defaults = SubscriptionSheetLabels(
    renewsOn: 'Renews',
    upgradePlan: 'Upgrade Plan',
    managePlan: 'Manage Subscription',
    loadError: 'Could not load subscription',
    freePlanTitle: 'Free Plan',
    freePlanDesc: 'Upgrade to unlock Pro templates, exports, and community publishing.',
    activePlanTitle: 'Active Subscription',
  );
}
