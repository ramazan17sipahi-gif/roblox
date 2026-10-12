import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/flow_ui.dart';
import '../../utils/auth_messages.dart';
import '../widgets/auth_flow_layout.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authEnterEmailPassword)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(e, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthFlowLayout(
      title: l10n.authWelcomeBack,
      subtitle: l10n.authSignInContinue,
      footerPrompt: l10n.authNoAccountPrompt,
      footerAction: l10n.authSignup,
      onFooterAction: () => context.go('/auth/signup'),
      formChildren: [
        FlowTextField(
          label: l10n.authEmailAddress,
          hint: l10n.authEmailHint,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        FlowTextField(
          label: l10n.authPassword,
          hint: l10n.authPasswordHint,
          controller: _passwordController,
          isPassword: true,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_isSubmitting) _submit();
          },
          showPasswordLabel: l10n.authShowPassword,
          hidePasswordLabel: l10n.authHidePassword,
          trailingLabel: TextButton(
            onPressed: () => context.push('/auth/forgot-password'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(44, 32),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.authForgotPassword,
              style: FlowUi.body(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.isDark
                    ? AppColors.primaryContainer
                    : AppColors.primary,
                height: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FlowPrimaryButton(
          label: l10n.authSignIn,
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
