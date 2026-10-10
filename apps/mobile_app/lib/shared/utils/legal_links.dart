import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../l10n/generated/app_localizations.dart';

enum LegalDocument { privacy, terms, help }

bool isLegalUrlConfigured(String url) =>
    !url.contains('PASTE_') && url.startsWith('http');

String legalUrl(LegalDocument document) {
  switch (document) {
    case LegalDocument.privacy:
      return AppConfig.privacyUrl;
    case LegalDocument.terms:
      return AppConfig.termsUrl;
    case LegalDocument.help:
      return AppConfig.helpUrl;
  }
}

Future<void> openLegalDocument(
  BuildContext context,
  LegalDocument document,
) async {
  final l10n = AppLocalizations.of(context);
  final url = legalUrl(document);

  if (!isLegalUrlConfigured(url)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.legalDocumentUnavailable),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.legalLinkOpenFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> openSupportEmail(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final uri = Uri(
    scheme: 'mailto',
    path: AppConfig.supportEmail,
    queryParameters: {'subject': AppConfig.appNameShort},
  );

  if (!await launchUrl(uri) && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.legalLinkOpenFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
