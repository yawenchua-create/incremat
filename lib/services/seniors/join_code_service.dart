import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Creates and looks up "join codes" — the human-friendly credential (e.g.
/// `ROSE-4821`) a caregiver shares to link a senior to another caregiver's app.
///
/// SECURITY: a join code is a login-style credential. It's word+4 digits so it's
/// easy to read aloud, but it must be generated with a CRYPTOGRAPHIC random
/// source and never reused — hence `Random.secure()` and the uniqueness check.
class JoinCodeService {
  // The friendly word half of the code, kept short and unambiguous to say aloud.
  static const _words = [
    'ROSE', 'LAKE', 'DAWN', 'STAR', 'JADE',
    'FERN', 'OAK', 'BAY', 'REED', 'GROVE',
    'PINE', 'MOSS', 'SAGE', 'IRIS', 'WREN',
  ];

  // `Random.secure()` = an unpredictable, cryptographically-strong generator
  // (NOT the default `Random()`, which is guessable and unsafe for credentials).
  final _rng = Random.secure();
  final _db = FirebaseFirestore.instance;

  // Picks a random word and a random 4-digit number → "WORD-1234". `$word` is
  // string interpolation (drops the variable's value into the string).
  String _generate() {
    final word = _words[_rng.nextInt(_words.length)];
    final number = _rng.nextInt(9000) + 1000; // 1000–9999 (always 4 digits)
    return '$word-$number';
  }

  /// Generates a code guaranteed not to clash with an existing one, then claims
  /// it. Tries up to 20 times (collisions are rare with 15 words × 9000 numbers).
  Future<String> generateUniqueCode({
    required String seniorId,
    required String caregiverId,
  }) async {
    for (int attempts = 0; attempts < 20; attempts++) {
      final code = _generate();
      final ref = _db.collection('joinCodes').doc(code);
      try {
        // A TRANSACTION makes "check it's free, then claim it" ATOMIC: Firestore
        // guarantees no other device can grab the same code between the read and
        // the write. Without this, two caregivers could be handed the same code.
        await _db.runTransaction((tx) async {
          final snap = await tx.get(ref);
          if (snap.exists) throw Exception('collision'); // taken → try another
          tx.set(ref, {
            'seniorId': seniorId,
            'primaryCaregiverId': caregiverId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        return code; // success — the code is now reserved for this senior
      } catch (e) {
        // A collision just means "retry with a new code"; any other error is
        // real and re-thrown to the caller.
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
