import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:networking/networking.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthRepository(supabase);
});

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  Future<void> signInWithEmailPassword(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmailPassword(String email, String password, String username) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> deleteAccount() async {
    final res = await _supabase.functions.invoke('delete-account');
    if (res.status != 200) {
      throw Exception('delete-account failed: ${res.status}');
    }
    await _supabase.auth.signOut();
  }
}
