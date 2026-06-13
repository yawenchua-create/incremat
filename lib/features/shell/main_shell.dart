import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_session_provider.dart';
import '../../providers/mobility_alert_provider.dart';
import '../../services/notifications/push_service.dart';
import '../home/home_screen.dart';
import '../insights/insights_screen.dart';
import '../hardware/hardware_screen.dart';
import '../settings/settings_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    InsightsScreen(),
    HardwareScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Register this device for push so decline / fitness-check reminders reach
    // the caregiver even when the app is closed (delivered by the scheduled
    // Cloud Function in functions/).
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) PushService().register(uid);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Persist any in-progress session when the app is backgrounded so reps
    // aren't lost if the OS kills it.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(liveSessionProvider.notifier).flushNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Keep the mobility-decline watcher alive for the whole session so a
    // caregiver is alerted even when not viewing the affected senior.
    ref.watch(mobilityAlertWatcherProvider);
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: l.navHome,
      ),
      NavigationDestination(
        icon: const Icon(Icons.bar_chart_outlined),
        selectedIcon: const Icon(Icons.bar_chart),
        label: l.navInsights,
      ),
      NavigationDestination(
        icon: const Icon(Icons.watch_outlined),
        selectedIcon: const Icon(Icons.watch),
        label: l.navHardware,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: l.navSettings,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: destinations,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          animationDuration: const Duration(milliseconds: 300),
        ),
      ),
    );
  }
}

// Shared app bar used across feature screens
class IncrematAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;

  const IncrematAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: AppTextStyles.titleLarge),
      automaticallyImplyLeading: showBack,
      actions: actions,
    );
  }
}
