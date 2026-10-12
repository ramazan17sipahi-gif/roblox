import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/flow_ui.dart';
import '../../utils/auth_messages.dart';
import '../widgets/auth_flow_layout.dart';
import '../widgets/auth_legal_agreement.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.signOut().catchError((_) {});
  }

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
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (isSignupConfirmationRequired(response)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authCheckEmailSignup)),
        );
        context.go('/auth/login');
        return;
      }

      context.go('/home');
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
      title: l10n.authCreateAccount,
      subtitle: l10n.authStartCreating,
      footerPrompt: l10n.authHaveAccountPrompt,
      footerAction: l10n.authLogin,
      onFooterAction: () => context.go('/auth/login'),
      formChildren: [
        FlowTextField(
          label: l10n.authEmailAddress,
          hint: l10n.authEmailHint,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        FlowTextField(
          label: l10n.authPassword,
          hint: l10n.authPasswordMinHint,
          controller: _passwordController,
          isPassword: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_isSubmitting) _submit();
          },
          showPasswordLabel: l10n.authShowPassword,
          hidePasswordLabel: l10n.authHidePassword,
        ),
        const SizedBox(height: 24),
        FlowPrimaryButton(
          label: l10n.authSignUpWithEmail,
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
        const SizedBox(height: 14),
        const AuthLegalAgreement(),
      ],
    );
  }
}
