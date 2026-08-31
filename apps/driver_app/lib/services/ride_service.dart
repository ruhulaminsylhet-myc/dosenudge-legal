import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/models.dart';

class RideService {
  RideService._();
  static final instance = RideService._();

  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Open requests this driver can claim (dispatch pushes FCM too; this stream
  /// keeps the in-app list live).
  Stream<List<Ride>> openRequests() => _db
      .collection('rides')
      .where('status', isEqualTo: 'requested')
      .orderBy('requestedAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(Ride.fromDoc).toList());

  /// The ride this driver is currently working, if any.
  Stream<Ride?> activeRide() => _db
      .collection('rides')
      .where('driverId', isEqualTo: _uid)
      .where('status', whereIn: ['accepted', 'arrived', 'in_progress'])
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : Ride.fromDoc(s.docs.first));

  /// Atomic claim: succeeds only if the ride is still unassigned (enforced by
  /// both the transaction check and security rules).
  Future<bool> acceptRide(String rideId) async {
    final ref = _db.doc('rides/$rideId');
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null ||
            data['status'] != 'requested' ||
            data['driverId'] != null) {
          throw Exception('taken');
        }
        tx.update(ref, {'status': 'accepted', 'driverId': _uid});
      });
      return true;
    } catch (_) {
      return false; // another driver got there first
    }
  }

  Future<void> markArrived(String rideId) =>
      _db.doc('rides/$rideId').update({'status': 'arrived'});

  Future<void> startTrip(String rideId) =>
      _db.doc('rides/$rideId').update({'status': 'in_progress'});

  Future<void> completeTrip(String rideId) =>
      _db.doc('rides/$rideId').update({'status': 'completed'});

  Future<void> cancelRide(String rideId) => _db
      .doc('rides/$rideId')
      .update({'status': 'cancelled', 'cancelledBy': 'driver'});

  Stream<List<EarningsEntry>> earnings({int limit = 50}) => _db
      .collection('earnings')
      .where('driverId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(EarningsEntry.fromDoc).toList());
}
