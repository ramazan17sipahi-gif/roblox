import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:networking/networking.dart';

final creditsRepositoryProvider = Provider<CreditsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return CreditsRepository(supabase);
});

class CreditsRepository {
  final SupabaseClient _supabase;

  CreditsRepository(this._supabase);

  int _lastKnownBalance = 0;

  /// Streams the current user's authoritative credit balance via ledger events
  Stream<int> streamUserCredits() async* {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      yield 0;
      return;
    }

    // Initial fetch
    final initialBalance = await _fetchBalance(userId);
    yield initialBalance;

    // Listen to ledger changes
    await for (final _ in _supabase.from('credits_ledger').stream(primaryKey: ['id']).eq('user_id', userId)) {
      yield await _fetchBalance(userId);
    }
  }

  Future<int> _fetchBalance(String userId) async {
    try {
      final res = await _supabase.rpc('get_credits_balance', params: {'p_user_id': userId});
      _lastKnownBalance = (res as num?)?.toInt() ?? _lastKnownBalance;
      return _lastKnownBalance;
    } catch (e, stack) {
      // Log the concrete rpc failure
      debugPrint('Error fetching credits balance from RPC: \$e\\n\$stack');
      // Produce a safe fallback so the UI does not crash or incorrectly lock
      return _lastKnownBalance;
    }
  }
}
