import 'package:design_system/design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/utils/legal_links.dart';

class AuthLegalAgreement extends StatelessWidget {
  const AuthLegalAgreement({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.outlineVariant,
          height: 1.5,
        );
    final linkStyle = style?.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: l10n.authTermsAgreementPrefix),
          TextSpan(
            text: l10n.settingsTermsOfService,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openLegalDocument(context, LegalDocument.terms),
          ),
          TextSpan(text: l10n.authTermsAgreementMiddle),
          TextSpan(
            text: l10n.settingsPrivacyPolicy,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openLegalDocument(context, LegalDocument.privacy),
          ),
          TextSpan(text: l10n.authTermsAgreementSuffix),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
