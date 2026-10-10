import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';

final authRobloxServiceProvider = Provider<AuthRobloxService>((ref) {
  return AuthRobloxService(Supabase.instance.client);
});

class AuthRobloxLoginResult {
  final String accessToken;
  final String refreshToken;
  final String displayName;
  final String externalAccountId;
  final bool isNewUser;

  const AuthRobloxLoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.displayName,
    required this.externalAccountId,
    required this.isNewUser,
  });
}

/// Sign-in / sign-up with Roblox OAuth (no prior Supabase session required).
class AuthRobloxService {
  final SupabaseClient _supabase;

  AuthRobloxService(this._supabase);

  Future<AuthRobloxLoginResult> signInWithRoblox() async {
    final initResponse = await _supabase.functions.invoke(
      'auth-roblox-init',
      body: {
        'redirectUri': AppConfig.robloxOAuthRedirectUri,
      },
    );

    if (initResponse.status != 200) {
      throw Exception(_errorMessage(initResponse.data, 'Failed to start Roblox login'));
    }

    final init = Map<String, dynamic>.from(initResponse.data as Map);
    final authorizationUrl = init['authorizationUrl'] as String?;
    final state = init['state'] as String?;
    if (authorizationUrl == null || authorizationUrl.isEmpty || state == null || state.isEmpty) {
      throw Exception('Invalid Roblox login session');
    }

    final callback = await FlutterWebAuth2.authenticate(
      url: authorizationUrl,
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
    final returnedState = uri.queryParameters['state'];
    if (code == null || code.isEmpty) {
      throw Exception('Roblox authorization code missing');
    }
    if (returnedState != state) {
      throw Exception('OAuth state mismatch');
    }

    final finalizeResponse = await _supabase.functions.invoke(
      'auth-roblox-finalize',
      body: {
        'authorizationCode': code,
        'state': state,
      },
    );

    if (finalizeResponse.status != 200) {
      throw Exception(
        _errorMessage(finalizeResponse.data, 'Failed to complete Roblox login'),
      );
    }

    final data = Map<String, dynamic>.from(finalizeResponse.data as Map);
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw Exception('Roblox login did not return a session');
    }

    final authResponse = await _supabase.auth.setSession(refreshToken);
    if (authResponse.session == null) {
      throw Exception('Failed to establish Supabase session');
    }

    return AuthRobloxLoginResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      displayName: data['displayName'] as String? ?? 'Roblox User',
      externalAccountId: data['externalAccountId'] as String? ?? '',
      isNewUser: data['isNewUser'] == true,
    );
  }

  String _errorMessage(dynamic data, String fallback) {
    if (data is Map && data['error'] is Map) {
      return (data['error']['message'] as String?) ?? fallback;
    }
    return fallback;
  }
}
