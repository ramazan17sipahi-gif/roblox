import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../shared/widgets/flow_ui.dart';
import 'auth_roblox_button.dart';

/// Shared layout for the login and signup screens.
class AuthFlowLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> formChildren;
  final String footerPrompt;
  final String footerAction;
  final VoidCallback onFooterAction;

  const AuthFlowLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.formChildren,
    required this.footerPrompt,
    required this.footerAction,
    required this.onFooterAction,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canPop = context.canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                if (canPop)
                                  _BackButton(
                                    tooltip: MaterialLocalizations.of(context)
                                        .backButtonTooltip,
                                    onPressed: () => context.pop(),
                                  ),
                                const Spacer(),
                                const BrandLogo(size: 32, borderRadius: 9),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(title, style: FlowUi.display(size: 32)),
                          const SizedBox(height: 10),
                          Text(subtitle, style: FlowUi.body(size: 15)),
                          const SizedBox(height: 28),
                          const AuthRobloxButton(),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(color: AppColors.borderSubtle),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  l10n.authOrWithEmail,
                                  style: FlowUi.body(
                                    size: 13,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: AppColors.borderSubtle),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          ...formChildren,
                          const Spacer(),
                          const SizedBox(height: 24),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(footerPrompt, style: FlowUi.body(size: 15)),
                              TextButton(
                                onPressed: onFooterAction,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.onBackground,
                                  minimumSize: const Size(48, 44),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                ),
                                child: Text(
                                  footerAction,
                                  style: FlowUi.body(
                                    size: 15,
                                    weight: FontWeight.w800,
                                    color: AppColors.onBackground,
                                  ).copyWith(
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.onBackground,
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
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const _BackButton({required this.onPressed, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        backgroundColor: AppColors.surfaceContainerLowest,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      icon: Icon(Icons.arrow_back_rounded,
          size: 20, color: AppColors.onBackground),
    );
  }
}
