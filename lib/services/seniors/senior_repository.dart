import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/senior.dart';

class SeniorRepository {
  SeniorRepository(this._uid);

  final String _uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('users/$_uid/seniors');

  Stream<List<Senior>> watchAll() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs
              .map((d) => Senior.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Future<void> add({
    required String name,
    required int age,
    required int dailyRepGoal,
  }) async {
    final doc = _col.doc();
    await doc.set(
      Senior(id: doc.id, name: name, age: age, dailyRepGoal: dailyRepGoal)
          .toMap(),
    );
  }

  Future<void> updateGoal(String seniorId, int newGoal) async {
    await _col.doc(seniorId).update({'dailyRepGoal': newGoal});
  }

  Future<void> update(String seniorId, {required String name, required int age}) async {
    await _col.doc(seniorId).update({'name': name, 'age': age});
  }

  Future<void> delete(String seniorId) async {
    final sessionsSnap = await _col.doc(seniorId).collection('sessions').get();
    for (final doc in sessionsSnap.docs) {
      await doc.reference.delete();
    }
    await _col.doc(seniorId).delete();
  }
}
