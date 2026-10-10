import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:networking/networking.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notifies [GoRouter] when Supabase auth session changes.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Stream<AuthState> authStream) {
    _subscription = authStream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final notifier = RouterRefreshNotifier(client.auth.onAuthStateChange);
  ref.onDispose(notifier.dispose);
  return notifier;
});
