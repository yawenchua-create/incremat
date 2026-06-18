import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/chair_stand.dart';
import '../../models/senior.dart';
import 'join_code_service.dart';

/// Data-access layer for the seniors a given caregiver can see and edit.
///
/// Scoped to one caregiver (`_caregiverId`). The tricky part is [watchAll],
/// which composes TWO levels of live data: a list of senior-ids the caregiver
/// may access, and the document for each of those seniors — all kept live.
class SeniorRepository {
  SeniorRepository(this._caregiverId);

  final String _caregiverId;

  // Top-level `seniors` collection (every senior in the system).
  CollectionReference<Map<String, dynamic>> get _seniorsCol =>
      FirebaseFirestore.instance.collection('seniors');

  // This caregiver's "access list" doc — holds the array of seniorIds they're
  // allowed to see. Acts as the permission gate enforced by Firestore rules.
  DocumentReference<Map<String, dynamic>> get _accessDoc =>
      FirebaseFirestore.instance.collection('caregiver_access').doc(_caregiverId);

  /// Streams all seniors this caregiver has access to, with live updates.
  ///
  /// Watches /caregiver_access/{uid} for the senior ID list, and keeps a live
  /// .snapshots() subscription per senior document so that field changes
  /// (dailyRepGoal, consistencyThreshold, name, etc.) immediately propagate
  /// to the stream without requiring a full re-query.
  Stream<List<Senior>> watchAll() {
    // Per-senior live subscriptions, keyed by id, so we can add/cancel them as
    // the access list changes. `liveData` is the latest Senior for each id.
    final activeSubs = <String, StreamSubscription<dynamic>>{};
    final liveData = <String, Senior>{};
    // `late` = we promise to assign `controller` before it's used (it's
    // referenced inside the callbacks below but created just after).
    late StreamController<List<Senior>> controller;
    StreamSubscription<dynamic>? accessSub;

    // Pushes the current seniors (sorted by name) out to whoever's listening.
    void emit() {
      if (!controller.isClosed) {
        controller.add(
          liveData.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
        );
      }
    }

    void subscribeToSenior(String id) {
      activeSubs[id]?.cancel();
      activeSubs[id] = _seniorsCol.doc(id).snapshots().listen(
        (snap) {
          if (snap.exists) {
            liveData[id] = Senior.fromMap(snap.data()!, snap.id);
          } else {
            liveData.remove(id);
          }
          emit();
        },
        onError: (_) {
          liveData.remove(id);
          emit();
        },
      );
    }

    controller = StreamController<List<Senior>>(
      // onListen runs when the UI first subscribes. We watch the access doc and,
      // each time the id-list changes, diff old vs new using Set math:
      //   oldIds.difference(newIds) = ids removed → cancel & drop them
      //   newIds.difference(oldIds) = ids added   → start watching them
      // This way we only open/close the subscriptions that actually changed.
      onListen: () {
        accessSub = _accessDoc.snapshots().listen(
          (accessSnap) {
            final newIds = Set<String>.from(
              accessSnap.exists
                  ? List<String>.from(accessSnap.data()?['seniorIds'] ?? [])
                  : [],
            );
            final oldIds = activeSubs.keys.toSet();

            for (final id in oldIds.difference(newIds)) {
              activeSubs.remove(id)?.cancel();
              liveData.remove(id);
            }

            for (final id in newIds.difference(oldIds)) {
              subscribeToSenior(id);
            }

            if (newIds.isEmpty) emit(); // emit an empty list when access is gone
          },
          onError: controller.addError,
        );
      },
      // onCancel runs when the last listener leaves: tear everything down so no
      // Firestore subscriptions leak.
      onCancel: () {
        accessSub?.cancel();
        for (final sub in activeSubs.values) { sub.cancel(); }
        activeSubs.clear();
        liveData.clear();
      },
    );

    return controller.stream;
  }

  /// Creates a new senior, writes the caregiver subcollection entry, generates a join code,
  /// and returns the seniorId + join code.
  // Returns a record `({String seniorId, String joinCode})` so the caller gets
  // both values from one call (e.g. to show the new code on a success screen).
  Future<({String seniorId, String joinCode})> add({
    required String name,
    required int age,
    required Sex sex,
    required int dailyRepGoal,
  }) async {
    final docRef = _seniorsCol.doc(); // pre-allocate an id without writing yet
    final seniorId = docRef.id;

    // Generate unique join code and write /joinCodes/{code}.
    final codeService = JoinCodeService();
    final joinCode = await codeService.generateUniqueCode(
      seniorId: seniorId,
      caregiverId: _caregiverId,
    );

    final senior = Senior(
      id: seniorId,
      name: name,
      age: age,
      sex: sex,
      dailyRepGoal: dailyRepGoal,
      consistencyThreshold: 4,
      joinCode: joinCode,
      primaryCaregiverId: _caregiverId,
    );

    await docRef.set(senior.toMap());

    // Write the primary caregiver entry into the caregivers subcollection
    // (still needed for isCaregiverFor security rule checks).
    await docRef.collection('caregivers').doc(_caregiverId).set({
      'caregiverId': _caregiverId,
      'role': 'primary',
      'addedAt': FieldValue.serverTimestamp(),
    });

    // Register the senior ID in the caregiver's access document.
    await _accessDoc.set({
      'seniorIds': FieldValue.arrayUnion([seniorId]),
    }, SetOptions(merge: true));

    return (seniorId: seniorId, joinCode: joinCode);
  }

  Future<void> updateGoal(String seniorId, int newGoal) async {
    await _seniorsCol.doc(seniorId).update({'dailyRepGoal': newGoal});
  }

  /// Records a 30-Second Chair Stand Test result on the senior document.
  /// Optionally applies a new daily rep goal in the same write (used when the
  /// caregiver accepts the recommended starting goal).
  Future<void> recordChairStandTest(
    String seniorId,
    int reps, {
    int? newGoal,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _seniorsCol.doc(seniorId).update({
      'chairStandReps': reps,
      'chairStandTestAt': now,
      // `?newGoal` is Dart's null-aware MAP ENTRY: if newGoal is null this whole
      // key is omitted, so we only overwrite the goal when one was supplied.
      'dailyRepGoal': ?newGoal,
      // arrayUnion appends to the existing array WITHOUT rewriting it, so the
      // full chair-stand history grows for the monthly trend chart.
      'chairStandHistory': FieldValue.arrayUnion([
        {'reps': reps, 'at': now}
      ]),
    });
  }

  Future<void> update(String seniorId,
      {required String name, required int age, Sex? sex}) async {
    await _seniorsCol.doc(seniorId).update({
      'name': name,
      'age': age,
      'sex': ?sex?.name,
    });
  }

  Future<void> updateConsistencyThreshold(String seniorId, int threshold) async {
    await _seniorsCol.doc(seniorId).update({'consistencyThreshold': threshold});
  }

  /// Removes this caregiver's access to the senior (does NOT delete the senior
  /// document — other caregivers may still need it). Deletes the caregivers
  /// sub-entry and pulls the id out of this caregiver's access list.
  Future<void> delete(String seniorId) async {
    await _seniorsCol
        .doc(seniorId)
        .collection('caregivers')
        .doc(_caregiverId)
        .delete();
    await _accessDoc.update({
      'seniorIds': FieldValue.arrayRemove([seniorId]),
    });
  }

  /// Adds a secondary caregiver entry to an existing senior's caregivers subcollection.
  Future<void> addSecondaryCaregiver(String seniorId) async {
    await _seniorsCol.doc(seniorId).collection('caregivers').doc(_caregiverId).set({
      'caregiverId': _caregiverId,
      'role': 'secondary',
      'addedAt': FieldValue.serverTimestamp(),
    });
    await _accessDoc.set({
      'seniorIds': FieldValue.arrayUnion([seniorId]),
    }, SetOptions(merge: true));
  }

  /// Returns all senior IDs this caregiver has access to (used for account cleanup).
  Future<List<String>> getSeniorIds() async {
    final snap = await _accessDoc.get();
    if (!snap.exists) return [];
    return List<String>.from(snap.data()?['seniorIds'] ?? []);
  }
}
