import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../utils/auth_messages.dart';
import '../widgets/auth_legal_agreement.dart';
import '../widgets/auth_roblox_button.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          l10n.authSignup,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.authStartCreating,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textMediumEmphasis,
                              ),
                        ),
                        const SizedBox(height: 32),
                        const AuthRobloxButton(),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: Divider(color: AppColors.border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                l10n.authOrUseEmail,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.outlineVariant,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: AppColors.border)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        DSTextField(
                          controller: _emailController,
                          label: l10n.authEmailAddress,
                          hint: l10n.authEmailHint,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 24),
                        DSTextField(
                          controller: _passwordController,
                          label: l10n.authPassword,
                          hint: l10n.authPasswordHint,
                          obscureText: true,
                        ),
                        const SizedBox(height: 48),
                        DSButton(
                          label: l10n.authSignUpWithEmail,
                          onPressed: _isSubmitting ? null : _submit,
                        ),
                        const Spacer(),
                        const AuthLegalAgreement(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.authHaveAccount,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: () => context.go('/auth/login'),
                              child: Text(
                                l10n.authLogin,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
