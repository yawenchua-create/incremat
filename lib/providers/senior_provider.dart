import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/chair_stand.dart';
import '../l10n/app_localizations.dart';
import '../models/senior.dart';
import '../models/session_log.dart';
import '../services/notifications/notification_service.dart';
import '../services/nfc/nfc_uid_service.dart';
import '../services/seniors/join_code_service.dart';
import '../services/seniors/senior_repository.dart';
import '../services/seniors/session_repository.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
// The central STATE HUB for seniors and their sessions. This file wires the
// repositories (data layer) into providers (state layer) that screens watch.
// Recurring idea: a provider returns `null`/mock data when logged out, and real
// Firestore-backed data when authenticated — so demo mode "just works".
// ════════════════════════════════════════════════════════════════════════════

/// The repository for the LOGGED-IN caregiver, or null when signed out.
/// `.valueOrNull` reads the current user out of the auth AsyncValue without
/// throwing. Because it `ref.watch`es auth, it rebuilds on login/logout.
final seniorRepositoryProvider = Provider<SeniorRepository?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user != null ? SeniorRepository(user.uid) : null;
});

/// A session repository for a SPECIFIC senior. `Provider.family` = a provider
/// parameterised by an argument (here the seniorId); calling
/// `sessionRepositoryProvider('abc')` gives the repo for senior "abc".
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
// It's PRIVATE (`_` prefix) so screens can't set it directly — they must go
// through selectSenior() below, keeping selection logic in one place.
final _selectedSeniorIdProvider = StateProvider<String?>((ref) => null);

// Derives the active Senior object from the selection + seniors list. This is a
// "computed" provider: it watches two others and recombines them, so it
// recalculates whenever either the list or the selection changes.
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

// Who is physically on the mat right now (drives rep attribution), set ONLY by
// a real signal — an NFC tap on the mat — never by merely viewing a profile.
// null = no explicit signal yet; attribution then falls back to the selected
// senior at the moment a session starts, and locks for that session.
final activeExerciserIdProvider = StateProvider<String?>((ref) => null);

// True while a 30-Second Chair Stand Test is running, so the normal live-session
// pipeline ignores those reps instead of logging them as everyday exercise.
final chairStandTestActiveProvider = StateProvider<bool>((ref) => false);

/// [selectSenior] for callers holding a provider [Ref] rather than a WidgetRef
/// (e.g. the hardware NFC coordinator reacting to a mat tap).
void selectSeniorRef(Ref ref, String seniorId) {
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

// Sessions over the last 28 days — the window the mobility (5-rep) alert
// analysis needs for day-over-day and week-over-week comparisons.
final mobilityWindowSessionsProvider =
    StreamProvider.family<List<SessionLog>, String>((ref, seniorId) {
  final repo = ref.watch(sessionRepositoryProvider(seniorId));
  if (repo == null) return Stream.value([]);
  final since = DateTime.now().subtract(const Duration(days: 28));
  return repo.watchSince(since);
});

// Music track selection per senior (keyed by senior id).
final selectedTrackProvider =
    StateProvider.family<String?, String>((ref, _) => null);

final randomizeTracksProvider =
    StateProvider.family<bool, String>((ref, _) => true);

// Notifier for WRITE operations. Its state is `void` because it holds no data —
// it's just a home for action methods the UI calls (add/update/delete/connect).
// Each method grabs the repo with ref.read (one-off, no subscription) and
// returns early if logged out (repo == null).
class SeniorsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Creates a new senior and returns the seniorId + join code.
  Future<({String seniorId, String joinCode})?> addSenior({
    required String name,
    required int age,
    required Sex sex,
    required int dailyRepGoal,
  }) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return null;
    return await repo.add(
        name: name, age: age, sex: sex, dailyRepGoal: dailyRepGoal);
  }

  Future<void> updateSenior(
    String seniorId, {
    required String name,
    required int age,
    Sex? sex,
  }) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return;
    await repo.update(seniorId, name: name, age: age, sex: sex);
  }

  Future<void> updateGoal(String seniorId, int newGoal) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return;
    await repo.updateGoal(seniorId, newGoal);
  }

  /// Saves a 30-Second Chair Stand Test result; if [newGoal] is given it also
  /// applies that as the daily rep goal in the same write.
  Future<void> recordChairStandTest(
    String seniorId,
    int reps, {
    int? newGoal,
  }) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return;
    await repo.recordChairStandTest(seniorId, reps, newGoal: newGoal);
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
  Future<String?> connectSenior(String code, AppLocalizations l) async {
    final seniorId = await JoinCodeService().lookup(code);
    if (seniorId == null) return l.codeNotFound;
    return _connectToSenior(seniorId, l);
  }

  /// Connects the current caregiver to an existing senior by the UID of a card
  /// that has already been enrolled to that senior (e.g. via [NfcWriteSheet]).
  /// Returns null on success, or an error message string.
  Future<String?> connectSeniorByNfcUid(String uid, AppLocalizations l) async {
    final seniorId = await NfcUidService().lookup(uid);
    if (seniorId == null) return l.cardNotLinked;
    return _connectToSenior(seniorId, l);
  }

  /// Shared connect path: validates the senior exists, isn't already monitored,
  /// then adds the current caregiver as a secondary caregiver.
  Future<String?> _connectToSenior(String seniorId, AppLocalizations l) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return l.notSignedIn;
    final seniorDoc = await FirebaseFirestore.instance
        .collection('seniors')
        .doc(seniorId)
        .get();
    if (!seniorDoc.exists) return l.codeNotFound;
    // Check if already connected.
    final existing = await FirebaseFirestore.instance
        .collection('seniors/$seniorId/caregivers')
        .doc(user.uid)
        .get();
    if (existing.exists) return l.alreadyMonitoring;
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return l.notSignedIn;
    await repo.addSecondaryCaregiver(seniorId);
    return null;
  }
}

final seniorsNotifierProvider =
    NotifierProvider<SeniorsNotifier, void>(SeniorsNotifier.new);
