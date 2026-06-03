import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/senior.dart';
import 'join_code_service.dart';

class SeniorRepository {
  SeniorRepository(this._caregiverId);

  final String _caregiverId;

  CollectionReference<Map<String, dynamic>> get _seniorsCol =>
      FirebaseFirestore.instance.collection('seniors');

  DocumentReference<Map<String, dynamic>> get _accessDoc =>
      FirebaseFirestore.instance.collection('caregiver_access').doc(_caregiverId);

  /// Streams all seniors this caregiver has access to, with live updates.
  ///
  /// Watches /caregiver_access/{uid} for the senior ID list, and keeps a live
  /// .snapshots() subscription per senior document so that field changes
  /// (dailyRepGoal, consistencyThreshold, name, etc.) immediately propagate
  /// to the stream without requiring a full re-query.
  Stream<List<Senior>> watchAll() {
    final activeSubs = <String, StreamSubscription<dynamic>>{};
    final liveData = <String, Senior>{};
    late StreamController<List<Senior>> controller;
    StreamSubscription<dynamic>? accessSub;

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

            if (newIds.isEmpty) emit();
          },
          onError: controller.addError,
        );
      },
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
  Future<({String seniorId, String joinCode})> add({
    required String name,
    required int age,
    required int dailyRepGoal,
  }) async {
    final docRef = _seniorsCol.doc();
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

  Future<void> update(String seniorId, {required String name, required int age}) async {
    await _seniorsCol.doc(seniorId).update({'name': name, 'age': age});
  }

  Future<void> updateConsistencyThreshold(String seniorId, int threshold) async {
    await _seniorsCol.doc(seniorId).update({'consistencyThreshold': threshold});
  }

  /// Removes this caregiver's access to the senior (does not delete the senior document).
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
