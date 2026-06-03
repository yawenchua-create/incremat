import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/senior.dart';
import '../models/session_log.dart';
import '../services/notifications/notification_service.dart';
import '../services/seniors/join_code_service.dart';
import '../services/seniors/senior_repository.dart';
import '../services/seniors/session_repository.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';

final seniorRepositoryProvider = Provider<SeniorRepository?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user != null ? SeniorRepository(user.uid) : null;
});

// Session repository no longer needs the caregiver uid — path is /seniors/{id}/sessions/.
final sessionRepositoryProvider =
    Provider.family<SessionRepository?, String>((ref, seniorId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user != null ? SessionRepository(seniorId) : null;
});

// Firestore stream — returns real data when authenticated, mock when logged out.
final seniorsStreamProvider = StreamProvider<List<Senior>>((ref) {
  final repo = ref.watch(seniorRepositoryProvider);
  if (repo == null) return Stream.value(List<Senior>.unmodifiable(MockSeniors.all));
  return repo.watchAll();
});

// Sync alias: mock data only for unauthenticated users (demo mode).
final seniorsProvider = Provider<List<Senior>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final list = ref.watch(seniorsStreamProvider).valueOrNull;
  if (user == null) return MockSeniors.all;
  return list ?? [];
});

// Holds the explicit senior ID selection; null = auto-select first.
final _selectedSeniorIdProvider = StateProvider<String?>((ref) => null);

// Derives the active Senior object from the selection + seniors list.
final selectedSeniorProvider = Provider<Senior?>((ref) {
  final seniors = ref.watch(seniorsProvider);
  if (seniors.isEmpty) return null;
  final id = ref.watch(_selectedSeniorIdProvider);
  if (id != null) {
    final match = seniors.where((s) => s.id == id).firstOrNull;
    if (match != null) return match;
  }
  return seniors.first;
});

void selectSenior(WidgetRef ref, String seniorId) {
  ref.read(_selectedSeniorIdProvider.notifier).state = seniorId;
}

// Recent sessions stream per senior.
final recentSessionsProvider =
    StreamProvider.family<List<SessionLog>, String>((ref, seniorId) {
  final repo = ref.watch(sessionRepositoryProvider(seniorId));
  if (repo == null) return Stream.value([]);
  return repo.watchRecent();
});

// All sessions since the start of the current week or month (whichever is earlier).
final monthlySessionsProvider =
    StreamProvider.family<List<SessionLog>, String>((ref, seniorId) {
  final repo = ref.watch(sessionRepositoryProvider(seniorId));
  if (repo == null) return Stream.value([]);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final today = DateTime(now.year, now.month, now.day);
  final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
  final since = startOfWeek.isBefore(startOfMonth) ? startOfWeek : startOfMonth;
  return repo.watchSince(since);
});

// Music track selection per senior (keyed by senior id).
final selectedTrackProvider =
    StateProvider.family<String?, String>((ref, _) => null);

final randomizeTracksProvider =
    StateProvider.family<bool, String>((ref, _) => true);

// Notifier for write operations (add / update / delete / connect).
class SeniorsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Creates a new senior and returns the seniorId + join code.
  Future<({String seniorId, String joinCode})?> addSenior({
    required String name,
    required int age,
    required int dailyRepGoal,
  }) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return null;
    return await repo.add(name: name, age: age, dailyRepGoal: dailyRepGoal);
  }

  Future<void> updateSenior(
    String seniorId, {
    required String name,
    required int age,
  }) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return;
    await repo.update(seniorId, name: name, age: age);
  }

  Future<void> updateGoal(String seniorId, int newGoal) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return;
    await repo.updateGoal(seniorId, newGoal);
  }

  Future<void> updateConsistencyThreshold(String seniorId, int threshold) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return;
    await repo.updateConsistencyThreshold(seniorId, threshold);
  }

  /// Removes the caregiver's own access to the senior (does not delete the senior).
  Future<void> deleteSenior(String seniorId) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return;
    final enabled =
        ref.read(notificationsProvider(seniorId)).valueOrNull ?? false;
    if (enabled) {
      await NotificationService().cancelGoalReminder(seniorId);
    }
    await repo.delete(seniorId);
  }

  /// Connects the current caregiver to an existing senior via join code.
  /// Returns null on success, or an error message string.
  Future<String?> connectSenior(String code) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return 'Not signed in';
    final seniorId = await JoinCodeService().lookup(code);
    if (seniorId == null) {
      return "That code wasn't found. Please check with the primary caregiver.";
    }
    // Check if already connected.
    final existing = await FirebaseFirestore.instance
        .collection('seniors/$seniorId/caregivers')
        .doc(user.uid)
        .get();
    if (existing.exists) return "You're already monitoring this person.";
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return 'Not signed in';
    await repo.addSecondaryCaregiver(seniorId);
    return null;
  }
}

final seniorsNotifierProvider =
    NotifierProvider<SeniorsNotifier, void>(SeniorsNotifier.new);
