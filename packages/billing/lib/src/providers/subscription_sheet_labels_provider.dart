import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_sheet_labels.dart';

final subscriptionSheetLabelsProvider = Provider<SubscriptionSheetLabels>(
  (_) => SubscriptionSheetLabels.defaults,
);

/// Bottom navigation / home shell clearance so sheet CTAs stay visible.
const kSubscriptionSheetBottomClearance = 88.0;
