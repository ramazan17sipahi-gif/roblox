import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:billing/billing.dart';
import 'link_roblox_page.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../app/app_providers.dart';
import '../../../../shared/utils/legal_links.dart';
import '../../../auth/data/auth_repository.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _displayName = '';
  String _email = '';
  String? _avatarUrl;
  String? _robloxUsername;
  bool _robloxLinked = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _email = user.email ?? '';
        _displayName = user.userMetadata?['display_name'] as String? ??
            user.userMetadata?['full_name'] as String? ??
            user.email?.split('@').first ??
            'User';
        _avatarUrl = user.userMetadata?['avatar_url'] as String?;
      });

      // Try to fetch profile from profiles table
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null && mounted) {
          setState(() {
            _displayName = profile['username'] as String? ?? _displayName;
            _avatarUrl = profile['avatar_url'] as String? ?? _avatarUrl;
          });
        }
        // Check Roblox link status
        try {
          final robloxLink = await Supabase.instance.client
              .from('linked_accounts')
              .select('display_name, status_code')
              .eq('user_id', user.id)
              .eq('platform_code', 'roblox')
              .maybeSingle();
          if (robloxLink != null && mounted) {
            final status = robloxLink['status_code'] as String? ?? 'pending';
            if (status == 'active') {
              setState(() {
                _robloxLinked = true;
                _robloxUsername = robloxLink['display_name'] as String?;
              });
            }
          }
        } catch (e) {
          debugPrint('Roblox link check error: $e');
        }
      } catch (e) {
        debugPrint('Profile fetch error: $e');
      }
    }
  }

  Future<void> _openLegal(LegalDocument document) =>
      openLegalDocument(context, document);

  void _showDeleteAccountDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDeleteConfirmTitle),
        content: Text(l10n.settingsDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(authRepositoryProvider).deleteAccount();
                if (!context.mounted) return;
                context.go('/auth/login');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.settingsDeleteSuccess),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.settingsDeleteFailed),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              l10n.commonDelete,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet(BuildContext context, String title, List<String> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item, style: const TextStyle(fontWeight: FontWeight.w500))),
                ],
              ),
            )),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).commonDone,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    final languages = <Map<String, String>>[
      {'code': 'en', 'flag': '🇬🇧', 'name': 'English'},
      {'code': 'tr', 'flag': '🇹🇷', 'name': 'Türkçe'},
      {'code': 'de', 'flag': '🇩🇪', 'name': 'Deutsch'},
      {'code': 'fr', 'flag': '🇫🇷', 'name': 'Français'},
      {'code': 'ar', 'flag': '🇸🇦', 'name': 'العربية'},
      {'code': 'ko', 'flag': '🇰🇷', 'name': '한국어'},
      {'code': 'id', 'flag': '🇮🇩', 'name': 'Bahasa'},
      {'code': 'ru', 'flag': '🇷🇺', 'name': 'Русский'},
      {'code': 'pt', 'flag': '🇧🇷', 'name': 'Português'},
      {'code': 'es', 'flag': '🇪🇸', 'name': 'Español'},
    ];

    final currentLocale = ref.read(localeProvider);
    final currentCode = currentLocale?.languageCode ??
        Localizations.localeOf(context).languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context).settingsLanguage, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ...languages.map((lang) {
              final isSelected = lang['code'] == currentCode;
              return GestureDetector(
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(Locale(lang['code']!));
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(lang['flag']!, style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          lang['name']!,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 16,
                            color: isSelected ? AppColors.primary : AppColors.onBackground,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
                    ],
                  ),
                ),
              );
            }),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).authLogoutConfirmTitle),
        content: Text(AppLocalizations.of(context).authLogoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                context.go('/auth/login');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).authLoggedOut),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              AppLocalizations.of(context).authLogoutConfirmTitle,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(entitlementProvider);
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () => context.pop(),
        ),
        centerTitle: false,
        title: Text(
          AppLocalizations.of(context).settingsTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: AppColors.onBackground),
            onPressed: () => context.push('/notifications'),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Profile Header ──────────────────────────────────────
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceContainerLow,
                        border: Border.all(color: AppColors.primaryContainer, width: 2),
                      ),
                      child: ClipOval(
                        child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? Image.network(
                                _avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.person,
                                  size: 32,
                                  color: AppColors.outlineVariant,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 32,
                                color: AppColors.outlineVariant,
                              ),
                      ),
                    ),
                    SizedBox(height: 12),
                    // Display name
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _displayName.isNotEmpty ? _displayName : 'User',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        if (entitlement.canAccessProContent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppColors.actionGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entitlement.planCode.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Email
                    Text(
                      _email.isNotEmpty ? _email : '',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.outlineVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),

              // ── Account Section ─────────────────────────────────────
              Text(
                AppLocalizations.of(context).settingsAccount,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildListTile(
                      Icons.person,
                      AppLocalizations.of(context).settingsPersonalInfo,
                      AppLocalizations.of(context).settingsPersonalInfoSub,
                      () => _showInfoSheet(
                        context,
                        AppLocalizations.of(context).settingsPersonalInfo,
                        [
                          '${AppLocalizations.of(context).settingsAccountName}: $_displayName',
                          '${AppLocalizations.of(context).settingsAccountEmail}: $_email',
                          '${AppLocalizations.of(context).settingsAccountId}: ${Supabase.instance.client.auth.currentUser?.id?.substring(0, 8) ?? "N/A"}...',
                          '${AppLocalizations.of(context).settingsAccountCreated}: ${_formatDate(Supabase.instance.client.auth.currentUser?.createdAt)}',
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildListTile(
                      Icons.shield,
                      AppLocalizations.of(context).settingsSecurity,
                      AppLocalizations.of(context).settingsSecuritySub,
                      () => _showInfoSheet(
                        context,
                        AppLocalizations.of(context).settingsSecurity,
                        [
                          '${Supabase.instance.client.auth.currentUser?.emailConfirmedAt != null ? AppLocalizations.of(context).settingsEmailVerified : AppLocalizations.of(context).settingsEmailNotVerified}',
                          '${AppLocalizations.of(context).settingsLastSignIn}: ${_formatDate(Supabase.instance.client.auth.currentUser?.lastSignInAt)}',
                          '${AppLocalizations.of(context).settingsLoginMethod}: ${Supabase.instance.client.auth.currentUser?.appMetadata["provider"] ?? "email"}',
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Linked Platform (Roblox only) ───────────────────────
              Text(
                AppLocalizations.of(context).settingsLinkedPlatforms,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildPlatformTile(
                  'Roblox',
                  _robloxLinked && _robloxUsername != null
                      ? '@$_robloxUsername'
                      : AppLocalizations.of(context).settingsRobloxStudioSync,
                  const Color(0xFF000000),
                  Icons.pentagon,
                  _robloxLinked ? AppLocalizations.of(context).linkedStatus : AppLocalizations.of(context).notLinkedStatus,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LinkRobloxPage()),
                    );
                    if (result == true) {
                      _loadUserData(); // Refresh data after linking
                    }
                  },
                ),
              ),
              SizedBox(height: 32),

              // ── Preferences Section ─────────────────────────────────
              Text(
                AppLocalizations.of(context).settingsPreferences,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Language Selection
                    GestureDetector(
                      onTap: () => _showLanguageSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.language, color: AppColors.primary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context).settingsLanguage,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    _currentLanguageName(context),
                                    style: TextStyle(fontSize: 12, color: AppColors.outlineVariant),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.outlineVariant),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: AppColors.surfaceContainerLow),
                    // Dark Mode Toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode : Icons.light_mode,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context).settingsDarkMode,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  isDark
                                      ? AppLocalizations.of(context).settingsDarkModeOn
                                      : AppLocalizations.of(context).settingsDarkModeOff,
                                  style: TextStyle(fontSize: 12, color: AppColors.outlineVariant),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isDark,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              ref.read(themeModeProvider.notifier).setThemeMode(
                                value ? ThemeMode.dark : ThemeMode.light,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: AppColors.surfaceContainerLow),
                    // Notifications
                    _buildBasicTile(
                      AppLocalizations.of(context).settingsNotifications,
                      Icons.chevron_right,
                      () => _showInfoSheet(
                        context,
                        AppLocalizations.of(context).settingsNotifications,
                        AppLocalizations.of(context).settingsNotificationData.split('|'),
                      ),
                    ),
                    Divider(height: 1, color: AppColors.surfaceContainerLow),
                    // Exports
                    _buildBasicTile(
                      AppLocalizations.of(context).settingsExports,
                      Icons.chevron_right,
                      () => _showInfoSheet(
                        context,
                        AppLocalizations.of(context).settingsExports,
                        AppLocalizations.of(context).settingsExportData.split('|'),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),

              // ── Subscription Card ───────────────────────────────────
              GestureDetector(
                onTap: () => context.push('/paywall'),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2F2D),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).settingsCurrentPlan,
                                style: const TextStyle(
                                  color: AppColors.primaryContainer,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entitlement.isFree
                                    ? l10n.settingsFreePlan
                                    : entitlement.isStudio
                                        ? l10n.settingsStudioPro
                                        : l10n.settingsProPlan,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          if (!entitlement.isFree)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                l10n.settingsMonthly,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        entitlement.isFree ? l10n.settingsFreePlanDesc : l10n.settingsPlanDesc,
                        style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: AppColors.actionGradient,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          entitlement.isFree
                              ? l10n.settingsUpgradeToPro
                              : l10n.settingsManageSubscription,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Tools & Features ────────────────────────────────────
              Text(
                AppLocalizations.of(context).settingsToolsFeatures,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildBasicTile(
                      AppLocalizations.of(context).settingsInviteEarn,
                      Icons.card_giftcard,
                      () => context.push('/referral'),
                    ),
                    Divider(height: 1, color: AppColors.surfaceContainerLow),
                    _buildBasicTile(
                      AppLocalizations.of(context).settingsTutorials,
                      Icons.school,
                      () => context.push('/tutorials'),
                    ),
                    Divider(height: 1, color: AppColors.surfaceContainerLow),
                    _buildBasicTile(
                      AppLocalizations.of(context).settingsAnalytics,
                      Icons.analytics,
                      () => context.push('/analytics'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),

              // ── Help & Legal ────────────────────────────────────────
              Text(
                AppLocalizations.of(context).settingsHelpLegal,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildBasicTile(
                      AppLocalizations.of(context).settingsHelpCenter,
                      Icons.open_in_new,
                      () => _openLegal(LegalDocument.help),
                    ),
                    Divider(height: 1, color: AppColors.surfaceContainerLow),
                    _buildBasicTile(
                      AppLocalizations.of(context).settingsSupportEmail,
                      Icons.mail_outline,
                      () => openSupportEmail(context),
                    ),
                    Divider(height: 1, color: AppColors.surfaceContainerLow),
                    _buildBasicTile(
                      AppLocalizations.of(context).settingsPrivacyPolicy,
                      Icons.chevron_right,
                      () => _openLegal(LegalDocument.privacy),
                    ),
                    Divider(height: 1, color: AppColors.surfaceContainerLow),
                    _buildBasicTile(
                      AppLocalizations.of(context).settingsTermsOfService,
                      Icons.chevron_right,
                      () => _openLegal(LegalDocument.terms),
                    ),
                    Divider(height: 1, color: AppColors.surfaceContainerLow),
                    _buildBasicTile(
                      AppLocalizations.of(context).settingsDeleteAccount,
                      Icons.delete_forever_outlined,
                      () => _showDeleteAccountDialog(context),
                      titleColor: AppColors.error,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),

              // ── Sign Out + Version ──────────────────────────────────
              Center(
                child: Column(
                  children: [
                    TextButton(
                      onPressed: () => _showSignOutDialog(context),
                      child: Text(
                        AppLocalizations.of(context).authLogoutButton,
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context).studioVersion,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.0,
                        color: AppColors.outlineVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper: Current language display name ─────────────────────────
  String _currentLanguageName(BuildContext context) {
    final currentLocale = ref.read(localeProvider);
    final code = currentLocale?.languageCode ??
        Localizations.localeOf(context).languageCode;
    const names = {
      'en': 'English',
      'tr': 'Türkçe',
      'de': 'Deutsch',
      'fr': 'Français',
      'ar': 'العربية',
      'ko': '한국어',
      'id': 'Bahasa',
      'ru': 'Русский',
      'pt': 'Português',
      'es': 'Español',
    };
    return names[code] ?? 'English';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  // ── Helper Widgets ────────────────────────────────────────────────

  Widget _buildListTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.outlineVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.outlineVariant),
        ],
      ),
    );
  }

  Widget _buildPlatformTile(
    String title,
    String subtitle,
    Color color,
    IconData icon,
    String status, {
    VoidCallback? onTap,
  }) {
    final bool isConnected = status != AppLocalizations.of(context).settingsNotLinked;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.outlineVariant)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected
                    ? const Color(0xFFA8FEC6).withOpacity(0.2)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isConnected ? const Color(0xFF06693F) : AppColors.outlineVariant,
                ),
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicTile(
    String title,
    IconData trailingIcon,
    VoidCallback onTap, {
    Color? titleColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            Icon(trailingIcon, color: titleColor ?? AppColors.outlineVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
