import 'dart:async';

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../core/geohash.dart';
import '../core/models.dart';

class DriverService {
  DriverService._();
  static final instance = DriverService._();

  final _db = FirebaseFirestore.instance;
  StreamSubscription<Position>? _locationSub;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _ref => _db.doc('drivers/$_uid');

  Stream<DriverProfile> profileStream() =>
      _ref.snapshots().map(DriverProfile.fromDoc);

  Future<bool> ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Going online = start streaming location into the driver doc so the
  /// dispatch function's geohash query can find this driver.
  Future<void> goOnline() async {
    if (!await ensureLocationPermission()) {
      throw Exception('Location permission is required to go online.');
    }
    final pos = await Geolocator.getCurrentPosition();
    await _writeLocation(pos, online: true);

    _locationSub?.cancel();
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25, // metres between updates — keeps writes cheap
      ),
    ).listen((pos) => _writeLocation(pos, online: true));
  }

  Future<void> goOffline() async {
    await _locationSub?.cancel();
    _locationSub = null;
    await _ref.update({
      'isOnline': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _writeLocation(Position pos, {required bool online}) async {
    await _ref.update({
      'isOnline': online,
      'location': GeoPoint(pos.latitude, pos.longitude),
      'geohash': Geohash.encode(pos.latitude, pos.longitude),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Uploads a verification document to `driver_docs/{uid}/` (storage rules
  /// restrict reads to the driver themself and admins) and records its URL on
  /// the driver profile so the admin panel can review it before approval.
  Future<void> uploadDocument(DriverDocument doc, File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final ref = FirebaseStorage.instance
        .ref('driver_docs/$_uid/${doc.key}.$ext');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    await _ref.update({
      'documents.${doc.key}': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveFcmToken(String token) async {
    await _ref.update({'fcmToken': token});
    await _db.doc('users/$_uid').update({'fcmToken': token});
  }

  void dispose() {
    _locationSub?.cancel();
    _locationSub = null;
  }
}
