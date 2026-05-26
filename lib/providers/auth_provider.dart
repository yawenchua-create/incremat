import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    return FirebaseAuth.instance.currentUser;
  }

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
      await cred.user?.updateDisplayName(name);
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
      // Re-authenticate before deletion — required by Firebase for sensitive ops.
      final cred = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      // Best-effort Firestore cleanup — don't block account deletion if it times out.
      try {
        final seniorsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('seniors');
        final snap = await seniorsRef.get().timeout(const Duration(seconds: 8));
        for (final doc in snap.docs) {
          final sessionsSnap = await doc.reference
              .collection('sessions')
              .get()
              .timeout(const Duration(seconds: 8));
          for (final sessionDoc in sessionsSnap.docs) {
            await sessionDoc.reference.delete();
          }
          await doc.reference.delete();
        }
      } catch (_) {
        // Cleanup timed out or failed; proceed with account deletion anyway.
      }
      await user.delete();
      return null;
    });
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);
