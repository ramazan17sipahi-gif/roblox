import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the global Supabase client instance.
/// Assumes [Supabase.initialize] has been called in main.dart / bootstrap.dart.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provides the current Supabase session (null if not authenticated).
final authSessionProvider = StreamProvider<Session?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange.map((event) => event.session);
});
