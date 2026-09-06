import 'package:firebase_messaging/firebase_messaging.dart';

/// Registers the device for push and keeps the FCM token synced to Firestore
/// via the provided callback. Ride-offer pushes carry data {type, rideId}.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;

  Future<void> init({
    required Future<void> Function(String token) onToken,
  }) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _messaging.getToken();
    if (token != null) await onToken(token);
    _messaging.onTokenRefresh.listen(onToken);
  }
}
