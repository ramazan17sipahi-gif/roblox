import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/auth_roblox_service.dart';

/// Shared "Continue with Roblox" control for login and signup.
class AuthRobloxButton extends ConsumerStatefulWidget {
  const AuthRobloxButton({super.key});

  @override
  ConsumerState<AuthRobloxButton> createState() => _AuthRobloxButtonState();
}

class _AuthRobloxButtonState extends ConsumerState<AuthRobloxButton> {
  bool _loading = false;

  Future<void> _onPressed() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      await ref.read(authRobloxServiceProvider).signInWithRoblox();
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      final message = raw.isNotEmpty && raw != e.runtimeType.toString()
          ? raw
          : l10n.authRobloxLoginFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DSButton(
      label: l10n.authContinueWithRoblox,
      icon: Icons.sports_esports_rounded,
      variant: DSButtonVariant.outline,
      isLoading: _loading,
      onPressed: _loading ? null : _onPressed,
    );
  }
}
