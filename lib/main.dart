import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_wrapper.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'services/notifications/notification_service.dart';

/// The app's ENTRY POINT — the first code that runs. `async` because startup
/// awaits a few one-time initialisations before showing any UI.
void main() async {
  // Required before using any plugins/native channels in main() — it boots the
  // Flutter engine bindings.
  WidgetsFlutterBinding.ensureInitialized();
  // Connect to Firebase using the per-platform config in firebase_options.dart.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Set up local notifications (timezone + channels) once at launch.
  await NotificationService().initialize();
  // `ProviderScope` is the ROOT that stores all Riverpod provider state — the
  // whole app must be wrapped in it. runApp inflates the widget tree on screen.
  runApp(const ProviderScope(child: IncrematApp()));
}

/// The root widget. `MaterialApp` provides navigation, theming and localization
/// to everything below it. It watches `localeProvider` so toggling the language
/// rebuilds the entire app in the new language.
class IncrematApp extends ConsumerWidget {
  const IncrematApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'IncreMat Caregiver',
      debugShowCheckedModeBanner: false, // hide the red debug ribbon
      theme: AppTheme.light,             // our brand theme (app_theme.dart)
      locale: locale,                    // current language
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthWrapper(),         // first screen = the auth gate
    );
  }
}