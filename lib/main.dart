import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_wrapper.dart';
import 'firebase_options.dart';
import 'services/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().initialize();
  runApp(const ProviderScope(child: IncrematApp()));
}

class IncrematApp extends StatelessWidget {
  const IncrematApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IncreMat Caregiver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthWrapper(),
    );
  }
}