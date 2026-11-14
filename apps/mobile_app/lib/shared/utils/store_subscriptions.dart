import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Opens the store's own subscription management page, where an active
/// subscriber can change or cancel the plan.
/// Apple: https://developer.apple.com/documentation/storekit/handling-subscriptions-billing
Future<void> openStoreSubscriptions() async {
  final uri = Uri.parse(Platform.isIOS
      ? 'https://apps.apple.com/account/subscriptions'
      : 'https://play.google.com/store/account/subscriptions');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
