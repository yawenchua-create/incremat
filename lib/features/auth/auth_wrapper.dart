import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../shell/main_shell.dart';
import 'account_creation_screen.dart';
import 'login_screen.dart';

/// The app's TOP-LEVEL GATE: decides which screen to show based on auth state.
/// A `ConsumerWidget` is a stateless widget that can read providers via `ref`.
/// It watches `authStateProvider` (the live login stream) and rebuilds whenever
/// the user signs in or out, so navigation follows auth automatically.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // `.when(...)` unpacks the AsyncValue into its three cases. This is the
    // idiomatic way to handle loading/error/data without manual null checks:
    return authState.when(
      // Signed in → the main app; signed out → the sign-up screen.
      data: (user) => user != null ? const MainShell() : const AccountCreationScreen(),
      // Still determining auth → a centered spinner.
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      // Auth stream errored → fall back to the login screen.
      error: (_, _) => const LoginScreen(),
    );
  }
}
