import '../../l10n/app_localizations.dart';

String friendlyAuthError(AppLocalizations l, Object? error) {
  final raw = error.toString();
  final codeMatch = RegExp(r'\[firebase_auth/([^\]]+)\]').firstMatch(raw);
  switch (codeMatch?.group(1) ?? '') {
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
      final idx = raw.lastIndexOf('] ');
      return idx == -1 ? l.errGeneric : raw.substring(idx + 2);
  }
}
