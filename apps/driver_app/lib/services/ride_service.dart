import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../core/models.dart';

class RideService {
  RideService._();
  static final instance = RideService._();

  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Open requests dispatch offered to *this* driver (it picks the nearest
  /// drivers to the pickup point). Security rules enforce the same scope, so a
  /// driver can never read requests outside their area.
  Stream<List<Ride>> openRequests() => _db
      .collection('rides')
      .where('status', isEqualTo: 'requested')
      .where('offeredTo', arrayContains: _uid)
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

  Future<void> startTrip(String rideId) async {
    await _db.doc('rides/$rideId').update({'status': 'in_progress'});
    _startMetering(rideId);
  }

  Future<void> completeTrip(String rideId) async {
    await _flushMeter(rideId);
    _stopMetering();
    await _db.doc('rides/$rideId').update({'status': 'completed'});
  }

  // ---------- trip meter ----------
  //
  // The fare is billed on the distance actually driven, so the trip is measured
  // here rather than assumed from the straight line. Writes are batched every
  // [_meterWriteThresholdKm] to keep Firestore writes down on a long trip; the
  // server clamps the total before charging anyone, so a bad reading can't
  // inflate a fare.

  static const _meterWriteThresholdKm = 0.2;

  StreamSubscription<Position>? _meterSub;
  Position? _lastMeterFix;
  double _meteredKm = 0;
  double _unwrittenKm = 0;

  void _startMetering(String rideId) {
    _stopMetering();
    _meteredKm = 0;
    _unwrittenKm = 0;
    _lastMeterFix = null;
    _meterSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) {
      final previous = _lastMeterFix;
      _lastMeterFix = pos;
      if (previous == null) return;

      // Drop jittery fixes: a poor GPS lock can otherwise add phantom metres
      // while the car is stationary.
      if (pos.accuracy > 50) return;

      final metres = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (metres < 5) return;

      final km = metres / 1000;
      _meteredKm += km;
      _unwrittenKm += km;
      if (_unwrittenKm >= _meterWriteThresholdKm) {
        _unwrittenKm = 0;
        _writeMeter(rideId);
      }
    });
  }

  Future<void> _flushMeter(String rideId) async {
    if (_meteredKm > 0) await _writeMeter(rideId);
  }

  Future<void> _writeMeter(String rideId) async {
    try {
      await _db.doc('rides/$rideId').update({
        'meteredDistanceKm': double.parse(_meteredKm.toStringAsFixed(3)),
      });
    } catch (_) {
      // A dropped write just means the next one carries the total; the value
      // is cumulative rather than incremental for exactly this reason.
    }
  }

  void _stopMetering() {
    _meterSub?.cancel();
    _meterSub = null;
  }

  void dispose() => _stopMetering();

  Future<void> cancelRide(String rideId) {
    _stopMetering();
    return _db
        .doc('rides/$rideId')
        .update({'status': 'cancelled', 'cancelledBy': 'driver'});
  }

  Stream<List<EarningsEntry>> earnings({int limit = 50}) => _db
      .collection('earnings')
      .where('driverId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(EarningsEntry.fromDoc).toList());
}
