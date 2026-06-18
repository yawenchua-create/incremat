import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/hardware/hardware_service.dart';
import '../services/nfc/nfc_uid_service.dart';
import 'auth_provider.dart';
import 'hardware_provider.dart';
import 'senior_provider.dart';

/// App-wide messenger so background events (e.g. an NFC tap on the mat) can
/// surface a SnackBar without a screen-local BuildContext.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Live NFC taps streamed from the mat (only emitted while connected).
final hardwareNfcTapProvider = StreamProvider<String>((ref) {
  return ref.watch(hardwareServiceProvider).nfcUidStream;
});

/// Buffered offline sessions the mat dumps after we request a sync.
final hardwareOfflineSessionProvider = StreamProvider<NfcOfflineSession>((ref) {
  return ref.watch(hardwareServiceProvider).offlineSessionStream;
});

/// UIDs this caregiver has enrolled — used to keep the mat's offline roster current.
final caregiverUidsProvider = StreamProvider<List<String>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return NfcUidService().watchUidsForCaregiver(user.uid);
});

/// Wires the mat's NFC hardware into the app:
///   • a card tapped on the mat switches the tracked senior (app-wide);
///   • the registered-user roster is pushed to the mat so it can attribute
///     reps offline, re-pushed whenever the enrolled set changes;
///   • on (re)connect, buffered offline sessions are pulled in and uploaded.
///
/// Kept alive for the app's lifetime by a `ref.watch` at the app root.
final nfcIdentityCoordinatorProvider = Provider<void>((ref) {
  final uidService = NfcUidService();

  // 1. Live taps from the mat → identify and switch the active senior.
  ref.listen(hardwareNfcTapProvider, (_, next) {
    final uidHex = next.valueOrNull;
    debugPrint('[NFC] coordinator received tap: $uidHex');
    if (uidHex == null || uidHex.isEmpty) return;
    _identify(ref, uidService, uidHex);
  });

  // 2. Buffered offline sessions arrive one notify at a time. Upload each as it
  //    lands, then ack (clearing the mat's buffer) once the dump goes quiet.
  Timer? ackTimer;
  ref.listen(hardwareOfflineSessionProvider, (_, next) {
    final session = next.valueOrNull;
    if (session == null) return;
    _uploadOffline(ref, uidService, session);
    ackTimer?.cancel();
    ackTimer = Timer(const Duration(seconds: 3), () {
      ref.read(hardwareServiceProvider).ackOfflineSync();
    });
  });

  // 3. On a fresh connection, sync the roster down and pull any buffered sessions.
  ref.listen(hardwareStatusProvider, (prev, next) {
    final wasConnected = prev?.valueOrNull?.isConnected ?? false;
    final isConnected = next.valueOrNull?.isConnected ?? false;
    if (isConnected && !wasConnected) {
      _syncRoster(ref);
      ref.read(hardwareServiceProvider).requestOfflineDump();
    }
  });

  // 4. Whenever the enrolled-UID set changes, re-push it (if currently connected).
  ref.listen(caregiverUidsProvider, (_, _) => _syncRoster(ref));

  ref.onDispose(() => ackTimer?.cancel());
});

Future<void> _identify(Ref ref, NfcUidService svc, String uidHex) async {
  final seniorId = await svc.lookup(uidHex);
  if (seniorId == null) {
    _toast((l) => l.cardNotRecognised);
    return;
  }
  final match = ref.read(seniorsProvider).where((s) => s.id == seniorId).firstOrNull;
  if (match == null) {
    _toast((l) => l.userNotInCircle);
    return;
  }
  // Mark who's physically on the mat: this is the "active exerciser" signal the
  // LiveSessionNotifier listens on to finalize the outgoing person's session and
  // re-baseline reps for the new user. Also switch the viewed senior so the UI
  // follows the tap.
  ref.read(activeExerciserIdProvider.notifier).state = seniorId;
  selectSeniorRef(ref, seniorId);
  _toast((l) => l.nowTracking(match.name));
}

Future<void> _uploadOffline(
    Ref ref, NfcUidService svc, NfcOfflineSession session) async {
  if (session.reps <= 0) return;
  final seniorId = await svc.lookup(session.uidHex);
  if (seniorId == null) return; // unknown card — nothing to attribute it to
  final repo = ref.read(sessionRepositoryProvider(seniorId));
  if (repo == null) return;
  // Mirror the live avg-rep-time maths: time spans rep 1 → last rep.
  final avg = (session.reps > 1 && session.durationMs > 0)
      ? (session.durationMs / 1000.0) / (session.reps - 1)
      : 0.0;
  await repo.add(repCount: session.reps, avgRepTimeSeconds: avg);
}

/// Wipes then re-pushes the full enrolled-UID set, but only while connected.
Future<void> _syncRoster(Ref ref) async {
  final status = ref.read(hardwareStatusProvider).valueOrNull;
  if (status == null || !status.isConnected) return;
  final uids = ref.read(caregiverUidsProvider).valueOrNull ?? const [];
  final hardware = ref.read(hardwareServiceProvider);
  await hardware.clearRoster();
  for (final uid in uids) {
    await hardware.pushKnownUid(uid);
  }
}

void _toast(String Function(AppLocalizations) message) {
  final messenger = scaffoldMessengerKey.currentState;
  final context = messenger?.context;
  if (messenger == null || context == null) {
    debugPrint('[NFC] no messenger available — cannot show toast');
    return;
  }
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message(AppLocalizations.of(context)))));
}
