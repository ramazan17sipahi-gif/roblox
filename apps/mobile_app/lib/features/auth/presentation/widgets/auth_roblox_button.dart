import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/auth_roblox_service.dart';
import '../../../../shared/widgets/flow_ui.dart';

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
    // Ink button: dark on light theme, light on dark theme.
    final bg = AppColors.onBackground;
    final fg = AppColors.background;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _loading ? null : _onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.6),
          disabledForegroundColor: fg.withValues(alpha: 0.8),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_esports_outlined, size: 22, color: fg),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.authContinueWithRoblox,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlowUi.body(
                        size: 16,
                        weight: FontWeight.w700,
                        color: fg,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
