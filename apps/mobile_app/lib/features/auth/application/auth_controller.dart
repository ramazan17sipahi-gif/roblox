import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AsyncData(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _repository.signInWithEmailPassword(email, password);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String username) async {
    state = const AsyncLoading();
    try {
      await _repository.signUpWithEmailPassword(email, password, username);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
