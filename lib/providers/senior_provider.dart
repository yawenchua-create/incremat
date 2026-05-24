import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/senior.dart';
import '../services/seniors/senior_repository.dart';
import 'auth_provider.dart';

// Repository scoped to the current user; null when logged out.
final seniorRepositoryProvider = Provider<SeniorRepository?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user != null ? SeniorRepository(user.uid) : null;
});

// Firestore stream — returns real data when authenticated, mock when logged out.
// An empty Firestore collection returns [] so HomeScreen can show an empty state.
final seniorsStreamProvider = StreamProvider<List<Senior>>((ref) {
  final repo = ref.watch(seniorRepositoryProvider);
  if (repo == null) return Stream.value(List<Senior>.unmodifiable(MockSeniors.all));
  return repo.watchAll();
});

// Sync alias used by screens that don't need a loading spinner.
// Falls back to mock (Betty) when the Firestore list is null or empty so that
// Insights / Settings always have a senior to display during the demo.
final seniorsProvider = Provider<List<Senior>>((ref) {
  final list = ref.watch(seniorsStreamProvider).valueOrNull;
  return (list == null || list.isEmpty) ? MockSeniors.all : list;
});

// Holds the explicit senior ID selection; null = auto-select first.
final _selectedSeniorIdProvider = StateProvider<String?>((ref) => null);

// Derives the active Senior object from the selection + seniors list.
// Falls back gracefully if the selected ID is no longer in the list.
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

// Music track selection per senior (keyed by senior id)
final selectedTrackProvider =
    StateProvider.family<String, String>((ref, _) => '甜蜜蜜');

final randomizeTracksProvider =
    StateProvider.family<bool, String>((ref, _) => true);

// Notifier for write operations (add / update / delete).
class SeniorsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> addSenior({
    required String name,
    required int age,
    required int dailyRepGoal,
  }) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return;
    await repo.add(name: name, age: age, dailyRepGoal: dailyRepGoal);
  }

  Future<void> updateGoal(String seniorId, int newGoal) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return;
    await repo.updateGoal(seniorId, newGoal);
  }

  Future<void> deleteSenior(String seniorId) async {
    final repo = ref.read(seniorRepositoryProvider);
    if (repo == null) return;
    await repo.delete(seniorId);
  }
}

final seniorsNotifierProvider =
    NotifierProvider<SeniorsNotifier, void>(SeniorsNotifier.new);
