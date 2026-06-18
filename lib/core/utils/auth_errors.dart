import '../../l10n/app_localizations.dart';

/// Translates a raw Firebase Auth exception into a friendly, localized message.
///
/// Firebase throws errors whose text looks like
/// `[firebase_auth/wrong-password] The password is invalid...`. We don't want
/// to show that to a user, so we:
///  1. pull the machine code (`wrong-password`) out with a regular expression,
///  2. map known codes to a translated sentence ([l] is the localizations bag),
///  3. fall back to a generic message for anything unrecognised.
String friendlyAuthError(AppLocalizations l, Object? error) {
  final raw = error.toString();
  // RegExp captures whatever sits between `[firebase_auth/` and the closing `]`.
  final codeMatch = RegExp(r'\[firebase_auth/([^\]]+)\]').firstMatch(raw);
  // group(1) is the captured code; `?? ''` handles the "no match" case.
  switch (codeMatch?.group(1) ?? '') {
    // Several codes all mean "those credentials were wrong" — collapse them into
    // one vague message on purpose (telling an attacker *which* part was wrong
    // would help them enumerate accounts).
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return l.errIncorrectCredentials;
    case 'email-already-in-use':
      return l.errEmailInUse;
    case 'weak-password':
      return l.errWeakPassword;
    case 'invalid-email':
      return l.errInvalidEmail;
    case 'user-disabled':
      return l.errUserDisabled;
    case 'too-many-requests':
      return l.errTooManyRequests;
    case 'network-request-failed':
      return l.errNoNetwork;
    case 'requires-recent-login':
      return l.errRecentLogin;
    default:
      // Unknown code: strip Firebase's `[...] ` prefix and show the remaining
      // human-readable sentence, or a generic fallback if there's no `] `.
      final idx = raw.lastIndexOf('] ');
      return idx == -1 ? l.errGeneric : raw.substring(idx + 2);
  }
}
