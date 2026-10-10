import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_config.dart';
import 'linked_accounts_repository.dart';

final robloxOAuthServiceProvider = Provider<RobloxOAuthService>((ref) {
  return RobloxOAuthService(ref.watch(linkedAccountsRepositoryProvider));
});

class RobloxOAuthService {
  final LinkedAccountsRepository _repository;

  RobloxOAuthService(this._repository);

  Future<RobloxOAuthFinalizeResult> connect() async {
    final init = await _repository.initRobloxOAuth();

    if (init.state.isEmpty) {
      throw Exception('Invalid OAuth session state');
    }

    final callback = await FlutterWebAuth2.authenticate(
      url: init.authorizationUrl,
      callbackUrlScheme: AppConfig.robloxOAuthCallbackScheme,
      options: const FlutterWebAuth2Options(
        intentFlags: 0,
        useWebview: true,
      ),
    );

    final uri = Uri.parse(callback);
    final error = uri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      final description = uri.queryParameters['error_description'];
      throw Exception(description ?? error);
    }

    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    if (code == null || code.isEmpty) {
      throw Exception('Roblox authorization code missing');
    }
    if (state != init.state) {
      throw Exception('OAuth state mismatch');
    }

    return _repository.finalizeRobloxOAuth(
      authorizationCode: code,
      state: state ?? init.state,
    );
  }
}
