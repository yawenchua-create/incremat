import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_wrapper.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/nfc_identity_provider.dart';
import 'services/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().initialize();
  runApp(const ProviderScope(child: IncrematApp()));
}

class IncrematApp extends ConsumerWidget {
  const IncrematApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    // Keep the mat NFC coordinator alive for the app's lifetime so taps switch
    // the tracked senior and offline sessions sync regardless of the open screen.
    ref.watch(nfcIdentityCoordinatorProvider);
    return MaterialApp(
      title: 'IncreMat Caregiver',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthWrapper(),
    );
  }
}