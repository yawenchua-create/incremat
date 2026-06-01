import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class JoinCodeService {
  static const _words = [
    'ROSE', 'LAKE', 'DAWN', 'STAR', 'JADE',
    'FERN', 'OAK', 'BAY', 'REED', 'GROVE',
    'PINE', 'MOSS', 'SAGE', 'IRIS', 'WREN',
  ];

  final _rng = Random.secure();
  final _db = FirebaseFirestore.instance;

  String _generate() {
    final word = _words[_rng.nextInt(_words.length)];
    final number = _rng.nextInt(9000) + 1000; // 1000–9999
    return '$word-$number';
  }

  Future<String> generateUniqueCode({
    required String seniorId,
    required String caregiverId,
  }) async {
    for (int attempts = 0; attempts < 20; attempts++) {
      final code = _generate();
      final ref = _db.collection('joinCodes').doc(code);
      try {
        await _db.runTransaction((tx) async {
          final snap = await tx.get(ref);
          if (snap.exists) throw Exception('collision');
          tx.set(ref, {
            'seniorId': seniorId,
            'primaryCaregiverId': caregiverId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        return code;
      } catch (e) {
        if (e.toString().contains('collision')) continue;
        rethrow;
      }
    }
    throw Exception('Could not generate a unique join code after 20 attempts');
  }

  /// Returns the seniorId for [code], or null if the code doesn't exist.
  Future<String?> lookup(String code) async {
    final doc = await _db.collection('joinCodes').doc(code.toUpperCase()).get();
    if (!doc.exists) return null;
    return doc.data()?['seniorId'] as String?;
  }
}
