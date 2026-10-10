import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:networking/networking.dart';
import '../../../config/app_config.dart';

final linkedAccountsRepositoryProvider = Provider<LinkedAccountsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return LinkedAccountsRepository(supabase);
});

class RobloxOAuthInitResult {
  final String authorizationUrl;
  final String state;
  final String redirectUri;

  const RobloxOAuthInitResult({
    required this.authorizationUrl,
    required this.state,
    required this.redirectUri,
  });

  factory RobloxOAuthInitResult.fromJson(Map<String, dynamic> json) {
    return RobloxOAuthInitResult(
      authorizationUrl: json['authorizationUrl'] as String,
      state: json['state'] as String,
      redirectUri: json['redirectUri'] as String? ?? AppConfig.robloxOAuthRedirectUri,
    );
  }
}

class RobloxOAuthFinalizeResult {
  final String displayName;
  final String externalAccountId;

  const RobloxOAuthFinalizeResult({
    required this.displayName,
    required this.externalAccountId,
  });

  factory RobloxOAuthFinalizeResult.fromJson(Map<String, dynamic> json) {
    return RobloxOAuthFinalizeResult(
      displayName: json['displayName'] as String? ?? 'Roblox User',
      externalAccountId: json['externalAccountId'] as String? ?? '',
    );
  }
}

class LinkedAccountsRepository {
  final SupabaseClient _supabase;

  LinkedAccountsRepository(this._supabase);

  Stream<List<Map<String, dynamic>>> streamLinkedAccounts() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('linked_accounts_safe')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId);
  }

  Future<RobloxOAuthInitResult> initRobloxOAuth() async {
    final response = await _supabase.functions.invoke(
      'link-platform-account-init',
      body: {
        'platformCode': 'roblox',
        'redirectUri': AppConfig.robloxOAuthRedirectUri,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      final message = data is Map && data['error'] is Map
          ? (data['error']['message'] as String? ?? 'Failed to start Roblox OAuth')
          : 'Failed to start Roblox OAuth';
      throw Exception(message);
    }

    return RobloxOAuthInitResult.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<RobloxOAuthFinalizeResult> finalizeRobloxOAuth({
    required String authorizationCode,
    required String state,
  }) async {
    final response = await _supabase.functions.invoke(
      'link-platform-account-finalize',
      body: {
        'platformCode': 'roblox',
        'authorizationCode': authorizationCode,
        'state': state,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      final message = data is Map && data['error'] is Map
          ? (data['error']['message'] as String? ?? 'Failed to complete Roblox OAuth')
          : 'Failed to complete Roblox OAuth';
      throw Exception(message);
    }

    return RobloxOAuthFinalizeResult.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> unlinkRobloxAccount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('linked_accounts')
        .delete()
        .eq('user_id', userId)
        .eq('platform_code', 'roblox');
  }

  Future<Map<String, dynamic>?> getActiveRobloxLink() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _supabase
        .from('linked_accounts_safe')
        .select('display_name, status_code, linked_at, external_account_id')
        .eq('user_id', userId)
        .eq('platform_code', 'roblox')
        .maybeSingle();

    if (row == null || row['status_code'] != 'active') return null;
    return row;
  }
}
