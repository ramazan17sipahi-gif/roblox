import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Maps Supabase auth errors to user-friendly localized messages.
String authErrorMessage(Object error, AppLocalizations l10n) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid email or password')) {
      return l10n.authLoginFailed;
    }
    if (message.contains('user already registered') ||
        message.contains('already been registered')) {
      return l10n.authEmailAlreadyRegistered;
    }
    if (message.contains('password should be at least')) {
      return l10n.authPasswordTooShort;
    }
    if (message.contains('unable to validate email') ||
        message.contains('invalid email')) {
      return l10n.authInvalidEmail;
    }
    if (message.contains('rate limit') || message.contains('too many requests')) {
      return l10n.authRateLimited;
    }
    return error.message;
  }

  final text = error.toString().toLowerCase();
  if (text.contains('network') || text.contains('socket')) {
    return l10n.errorNoInternet;
  }
  return l10n.commonUnexpectedError(error.toString());
}

bool isSignupConfirmationRequired(AuthResponse response) {
  final user = response.user;
  if (user == null) return false;
  return user.emailConfirmedAt == null && response.session == null;
}
