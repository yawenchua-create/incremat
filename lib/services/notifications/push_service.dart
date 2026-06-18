import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Registers this caregiver device for push so the scheduled Cloud Function can
/// deliver mobility-decline and fitness-check reminders even when the app is
/// closed. Tokens are stored on the caregiver's access document.
class PushService {
  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;

  /// Asks for push permission, grabs this device's FCM token, and saves it.
  /// (FCM = Firebase Cloud Messaging — Google's service that delivers a push to
  /// a specific device using its unique "token" address.) `onTokenRefresh`
  /// re-saves the token whenever Google rotates it, so deliveries keep working.
  Future<void> register(String caregiverId) async {
    try {
      await _messaging.requestPermission();
      final token = await _messaging.getToken();
      if (token != null) await _save(caregiverId, token);
      _messaging.onTokenRefresh.listen((t) => _save(caregiverId, t));
    } catch (_) {
      // Push is best-effort; the in-app alerts still work without it.
    }
  }

  Future<void> _save(String caregiverId, String token) async {
    try {
      await _db.collection('caregiver_access').doc(caregiverId).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
