import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';

import '../features/editor/data/editor_route_params.dart';
import '../features/editor/presentation/pages/editor_shell_page.dart';
import '../features/explore/presentation/pages/explore_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/notifications/presentation/pages/notifications_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/onboarding/presentation/pages/splash_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/templates/data/template_item_model.dart';
import '../features/templates/presentation/pages/templates_page.dart';
import '../features/templates/presentation/pages/template_preview_page.dart';
import '../features/profile/data/my_design_preview_params.dart';
import '../features/profile/presentation/pages/my_design_preview_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/settings/presentation/pages/link_roblox_page.dart';
import '../features/subscriptions/presentation/pages/paywall_page.dart';
import '../features/analytics/presentation/pages/analytics_page.dart';
import '../features/explore/presentation/pages/design_detail_page.dart';
import '../features/learn/presentation/pages/tutorials_page.dart';
import '../features/referral/presentation/pages/referral_page.dart';
import 'scaffold_shell.dart';
import 'router_refresh.dart';
import 'package:networking/networking.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Root navigator — full-screen routes must use [parentNavigatorKey] so they
/// open above the bottom-nav shell (otherwise push from Discover can no-op).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// Provide the GoRouter instance
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(supabaseClientProvider).auth.currentSession;
      final loc = state.matchedLocation;
      const publicPaths = {
        '/splash',
        '/onboarding',
        '/auth/login',
        '/auth/signup',
        '/auth/forgot-password',
      };
      final isPublic = publicPaths.contains(loc);

      if (session == null && !isPublic) {
        return '/auth/login';
      }
      if (session != null &&
          (loc == '/auth/login' || loc == '/auth/signup')) {
        return '/home';
      }
      return null;
    },
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/splash',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/template-preview',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra == null || extra is! TemplateItemModel) {
            // Type-safe guard: invalid param → error page with auto-pop
            return const _InvalidRouteGuardPage(
              message: 'Invalid template data',
            );
          }
          return TemplatePreviewPage(template: extra);
        },
      ),
      GoRoute(
        path: '/my-design-preview',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra == null || extra is! MyDesignPreviewParams) {
            // Type-safe guard: invalid param → error page with auto-pop
            return const _InvalidRouteGuardPage(
              message: 'Invalid design data',
            );
          }
          return MyDesignPreviewPage(design: extra);
        },
      ),
      GoRoute(
        path: '/editor',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          // Support both typed EditorRouteParams and legacy Map<String, dynamic>
          EditorMode mode = EditorMode.classicClothingBlankStart;
          ClothingTemplateType? template;
          String? shirtAssetPath;
          String? pantsAssetPath;
          String? projectId;

          final extra = state.extra;
          if (extra != null) {
            if (extra is EditorRouteParams) {
              mode = extra.mode;
              template = extra.clothingTemplate;
              shirtAssetPath = extra.shirtAssetPath;
              pantsAssetPath = extra.pantsAssetPath;
              projectId = extra.projectId;
            } else if (extra is Map<String, dynamic>) {
              mode = extra['mode'] as EditorMode? ?? EditorMode.classicClothingBlankStart;
            }
          }

          return CustomTransitionPage(
            key: state.pageKey,
            child: EditorShellPage(
              mode: mode,
              clothingTemplate: template,
              shirtAssetPath: shirtAssetPath,
              pantsAssetPath: pantsAssetPath,
              projectId: projectId,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeOutExpo;
              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/paywall',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PaywallPage(),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/auth/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/auth/signup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/analytics',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AnalyticsPage(),
      ),
      GoRoute(
        path: '/design_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map) {
            return DesignDetailPage(design: Map<String, dynamic>.from(extra));
          }
          return const DesignDetailPage();
        },
      ),
      GoRoute(
        path: '/link-roblox',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LinkRobloxPage(),
      ),
      GoRoute(
        path: '/tutorials',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TutorialsPage(),
      ),
      GoRoute(
        path: '/referral',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ExplorePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/templates',
                builder: (context, state) => const TemplatesPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Fallback page shown when route receives invalid or missing `extra` params.
/// Auto-pops after a brief delay and shows an error snackbar.
class _InvalidRouteGuardPage extends StatefulWidget {
  final String message;
  const _InvalidRouteGuardPage({required this.message});

  @override
  State<_InvalidRouteGuardPage> createState() => _InvalidRouteGuardPageState();
}

class _InvalidRouteGuardPageState extends State<_InvalidRouteGuardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
