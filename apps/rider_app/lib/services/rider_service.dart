import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

import '../core/models.dart';

class RiderService {
  RiderService._();
  static final instance = RiderService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  // Region must match setGlobalOptions in functions/src/index.ts.
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west2');

  String get _uid => _auth.currentUser!.uid;

  Stream<User?> get authState => _auth.authStateChanges();

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _db.doc('users/${cred.user!.uid}').set({
      'role': 'rider',
      'status': 'active',
      'name': name,
      'phone': phone,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    await cred.user!.getIdToken(true); // pick up role claim
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> registerPushToken() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token != null) {
      await _db.doc('users/$_uid').update({'fcmToken': token});
    }
    messaging.onTokenRefresh.listen(
      (t) => _db.doc('users/$_uid').update({'fcmToken': t}),
    );
  }

  // ---------- location & geocoding ----------

  Future<RidePoint> currentLocationPoint() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required.');
    }
    final pos = await Geolocator.getCurrentPosition();
    String address = 'Current location';
    try {
      final placemarks =
          await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = [p.street, p.locality, p.postalCode]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
      }
    } catch (_) {/* keep fallback label */}
    return RidePoint(lat: pos.latitude, lng: pos.longitude, address: address);
  }

  Future<RidePoint> geocodeAddress(String address) async {
    final results = await geocoding.locationFromAddress(address);
    if (results.isEmpty) throw Exception('Address not found: $address');
    final loc = results.first;
    return RidePoint(lat: loc.latitude, lng: loc.longitude, address: address);
  }

  // ---------- fares & rides ----------

  Future<Map<String, dynamic>> fareEstimate(
      RidePoint pickup, RidePoint dropoff) async {
    final result = await _functions.httpsCallable('getFareEstimate').call({
      'pickup': {'lat': pickup.lat, 'lng': pickup.lng},
      'dropoff': {'lat': dropoff.lat, 'lng': dropoff.lng},
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<String> requestRide({
    required RidePoint pickup,
    required RidePoint dropoff,
    required String riderName,
  }) async {
    final doc = await _db.collection('rides').add({
      'riderId': _uid,
      'riderName': riderName,
      'driverId': null,
      'status': 'requested',
      'pickup': pickup.toMap(),
      'dropoff': dropoff.toMap(),
      'estimatedDistanceKm': 0,
      'estimatedDurationMin': 0,
      'fareEstimate': null,
      'finalFare': null,
      'offeredTo': <String>[],
      'requestedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<Ride> rideStream(String rideId) =>
      _db.doc('rides/$rideId').snapshots().map(Ride.fromDoc);

  Stream<Ride?> openRide() => _db
      .collection('rides')
      .where('riderId', isEqualTo: _uid)
      .where('status',
          whereIn: ['requested', 'accepted', 'arrived', 'in_progress'])
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : Ride.fromDoc(s.docs.first));

  Stream<List<Ride>> history({int limit = 30}) => _db
      .collection('rides')
      .where('riderId', isEqualTo: _uid)
      .orderBy('requestedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Ride.fromDoc).toList());

  Future<void> cancelRide(String rideId) => _db
      .doc('rides/$rideId')
      .update({'status': 'cancelled', 'cancelledBy': 'rider'});

  /// Returns a Stripe Checkout URL for a completed, unpaid ride. The platform
  /// commission is taken as an application fee and the rest goes straight to
  /// the driver's connected account.
  Future<String> checkoutUrl(String rideId) async {
    final result = await _functions
        .httpsCallable('createRideCheckout')
        .call({'rideId': rideId});
    return (result.data as Map)['url'] as String;
  }

  /// Ratings go through a callable: security rules block clients from writing
  /// the driver's rating average directly.
  Future<void> rateRide(String rideId, int rating) async {
    await _functions.httpsCallable('rateRide').call({
      'rideId': rideId,
      'rating': rating,
    });
  }

  Future<String> displayName() async {
    final snap = await _db.doc('users/$_uid').get();
    return (snap.data()?['name'] ?? 'Rider') as String;
  }
}
