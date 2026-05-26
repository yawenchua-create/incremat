String friendlyAuthError(Object? error) {
  final raw = error.toString();
  final codeMatch = RegExp(r'\[firebase_auth/([^\]]+)\]').firstMatch(raw);
  switch (codeMatch?.group(1) ?? '') {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password. Please try again.';
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'weak-password':
      return 'Password must be at least 6 characters.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'user-disabled':
      return 'This account has been disabled. Please contact support.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'No internet connection. Please check your network.';
    case 'requires-recent-login':
      return 'Please sign in again before making this change.';
    default:
      final idx = raw.lastIndexOf('] ');
      return idx == -1 ? 'Something went wrong. Please try again.' : raw.substring(idx + 2);
  }
}
