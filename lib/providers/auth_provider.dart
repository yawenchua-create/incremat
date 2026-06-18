import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ───────────────────────── Riverpod in one paragraph ─────────────────────────
// Riverpod is this app's state manager. A "provider" is a globally-readable
// piece of state or logic. Widgets read providers with `ref.watch(x)` (and
// rebuild when x changes) or `ref.read(x)` (one-off, no rebuild). Common kinds:
//   • Provider        — a plain value/service that's computed once.
//   • StreamProvider  — exposes a Stream as an AsyncValue (loading/data/error).
//   • StateProvider   — a single mutable value (like a global setState).
//   • NotifierProvider / AsyncNotifierProvider — a class holding state + methods
//     that mutate it (the recommended pattern for non-trivial logic).
// ──────────────────────────────────────────────────────────────────────────────

/// LIVE auth state: emits the signed-in [User] (or null when signed out) and
/// re-emits on every login/logout. `authStateChanges()` is a Firebase stream;
/// wrapping it in a StreamProvider lets the whole app react to auth changes.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Holds auth ACTIONS (create account, sign in/out, delete). AsyncNotifier is a
/// Notifier whose state is an `AsyncValue<User?>` — so the UI can show loading
/// and error states automatically. `state` is the current value; setting it
/// rebuilds every watcher.
class AuthNotifier extends AsyncNotifier<User?> {
  // build() returns the INITIAL state when the provider is first read.
  @override
  Future<User?> build() async {
    return FirebaseAuth.instance.currentUser;
  }

  /// Registers a new caregiver. The pattern here repeats in signIn/delete:
  ///   1. `state = const AsyncLoading()` → UI shows a spinner.
  ///   2. `AsyncValue.guard(() async {...})` runs the work and AUTOMATICALLY
  ///      captures success as AsyncData or any thrown error as AsyncError — so
  ///      we never need a manual try/catch just to set error state.
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.updateDisplayName(name); // set the display name on signup
      return cred.user;
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    });
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount({required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      // Firebase blocks "sensitive" actions (like deleting an account) unless the
      // user signed in recently, so we re-verify their password first. The
      // EmailAuthProvider.credential bundles email+password into a credential
      // object that reauthenticateWithCredential checks.
      final cred = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      // Best-effort Firestore cleanup — remove caregiver subcollection entries.
      try {
        final accessDoc = await FirebaseFirestore.instance
            .collection('caregiver_access')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 8));
        final seniorIds = List<String>.from(
          accessDoc.data()?['seniorIds'] ?? [],
        );
        for (final seniorId in seniorIds) {
          await FirebaseFirestore.instance
              .collection('seniors')
              .doc(seniorId)
              .collection('caregivers')
              .doc(user.uid)
              .delete();
        }
        await accessDoc.reference.delete();
      } catch (_) {
        // Cleanup timed out or failed; proceed with account deletion anyway.
      }
      await user.delete();
      return null;
    });
  }
}

// The provider widgets actually read. `AuthNotifier.new` is the constructor
// passed as a factory; Riverpod calls it to create the notifier on first use.
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);
