import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:billing/billing.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_providers.dart';

import '../features/ads/ads_providers.dart';
import '../routing/app_router.dart';

/// The root application widget setting up theme and routing.
class CreatorApp extends ConsumerStatefulWidget {
  const CreatorApp({super.key});

  /// Supported locales for the application.
  static const _supportedLocales = [
    Locale('en'),
    Locale('tr'),
    Locale('de'),
    Locale('fr'),
    Locale('ar'),
    Locale('ko'),
    Locale('id'),
    Locale('ru'),
    Locale('pt'),
    Locale('es'),
  ];

  @override
  ConsumerState<CreatorApp> createState() => _CreatorAppState();
}

class _CreatorAppState extends ConsumerState<CreatorApp>
    with WidgetsBindingObserver {
  bool _initialOpenHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _showAppOpenAdForFreeUser();
    }
  }

  void _showAppOpenAdForFreeUser() {
    final wallet = ref.read(walletStateProvider).asData?.value;
    if (wallet == null || wallet.entitlement.canAccessProContent) return;
    unawaited(ref.read(appOpenAdServiceProvider).showIfAvailable());
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletStateProvider).asData?.value;
    if (!_initialOpenHandled && wallet != null) {
      _initialOpenHandled = true;
      if (!wallet.entitlement.canAccessProContent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAppOpenAdForFreeUser();
        });
      }
    }

    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'RBLX Clothing Maker',
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      builder: (context, child) {
        AppColors.bindToTheme(context);
        final l10n = AppLocalizations.of(context);
        if (child == null) return const SizedBox.shrink();

        return ProviderScope(
          overrides: [
            subscriptionSheetLabelsProvider.overrideWith(
              (_) => SubscriptionSheetLabels(
                renewsOn: l10n.subscriptionSheetRenewsOn,
                upgradePlan: l10n.subscriptionSheetUpgradePlan,
                managePlan: l10n.subscriptionSheetManagePlan,
                loadError: l10n.subscriptionSheetLoadError,
                freePlanTitle: l10n.subscriptionSheetFreeTitle,
                freePlanDesc: l10n.subscriptionSheetFreeDesc,
                activePlanTitle: l10n.subscriptionSheetActiveTitle,
              ),
            ),
          ],
          child: child,
        );
      },
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      routerConfig: router,
      debugShowCheckedModeBanner: false,

      // ── Localization ──────────────────────────────────────────
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: CreatorApp._supportedLocales,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        // Match device language to a supported locale
        for (final locale in supportedLocales) {
          if (locale.languageCode == deviceLocale?.languageCode) {
            return locale;
          }
        }
        // Fallback to English
        return const Locale('en');
      },
    );
  }
}
