import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/models.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Registers a driver: auth account + users profile + drivers application
  /// (approvalStatus always starts 'pending'; only admin can approve).
  Future<void> registerDriver({
    required String email,
    required String password,
    required String name,
    required String phone,
    required Vehicle vehicle,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    final batch = _db.batch();
    batch.set(_db.doc('users/$uid'), {
      'role': 'driver',
      'status': 'active',
      'name': name,
      'phone': phone,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.doc('drivers/$uid'), {
      'name': name,
      'phone': phone,
      'approvalStatus': 'pending',
      'isOnline': false,
      'vehicle': vehicle.toMap(),
      'rating': 0,
      'ratingCount': 0,
      'totalRides': 0,
      'totalEarnings': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    // Custom role claim is set server-side by the onUserCreated trigger;
    // refresh the token so security rules see role=driver on this device.
    await Future<void>.delayed(const Duration(seconds: 2));
    await cred.user!.getIdToken(true);
  }

  Future<void> signOut() => _auth.signOut();
}
