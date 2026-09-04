import 'package:cloud_firestore/cloud_firestore.dart';

class RidePoint {
  final double lat;
  final double lng;
  final String address;

  const RidePoint({required this.lat, required this.lng, required this.address});

  factory RidePoint.fromMap(Map<String, dynamic>? m) => RidePoint(
        lat: ((m?['lat'] ?? 0) as num).toDouble(),
        lng: ((m?['lng'] ?? 0) as num).toDouble(),
        address: (m?['address'] ?? '') as String,
      );

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 'address': address};
}

class Fare {
  final String currency;
  final double total;

  const Fare({required this.currency, required this.total});

  static Fare? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return Fare(
      currency: (m['currency'] ?? '') as String,
      total: ((m['total'] ?? 0) as num).toDouble(),
    );
  }

  String get label => '$currency ${total.toStringAsFixed(2)}';
}

/// Payment state for a ride. Only the Stripe webhook ever sets 'paid'.
class RidePayment {
  final String status; // pending | paid | failed
  final double amount;
  final String currency;

  const RidePayment({
    required this.status,
    required this.amount,
    required this.currency,
  });

  static RidePayment? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return RidePayment(
      status: (m['status'] ?? 'pending') as String,
      amount: ((m['amount'] ?? 0) as num).toDouble(),
      currency: (m['currency'] ?? '') as String,
    );
  }

  bool get isPaid => status == 'paid';
}

class Ride {
  final String id;
  final String riderId;
  final String? driverId;
  final String status;
  final RidePoint pickup;
  final RidePoint dropoff;
  final double estimatedDistanceKm;
  final Fare? fareEstimate;
  final Fare? finalFare;
  final Timestamp? requestedAt;
  final int? rating;
  final DriverInfo? driverInfo;
  final RidePayment? payment;

  const Ride({
    required this.id,
    required this.riderId,
    required this.driverId,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.estimatedDistanceKm,
    required this.fareEstimate,
    required this.finalFare,
    required this.requestedAt,
    required this.rating,
    required this.driverInfo,
    required this.payment,
  });

  factory Ride.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Ride(
      id: doc.id,
      riderId: (d['riderId'] ?? '') as String,
      driverId: d['driverId'] as String?,
      status: (d['status'] ?? 'requested') as String,
      pickup: RidePoint.fromMap(d['pickup'] as Map<String, dynamic>?),
      dropoff: RidePoint.fromMap(d['dropoff'] as Map<String, dynamic>?),
      estimatedDistanceKm:
          ((d['estimatedDistanceKm'] ?? 0) as num).toDouble(),
      fareEstimate: Fare.fromMap(d['fareEstimate'] as Map<String, dynamic>?),
      finalFare: Fare.fromMap(d['finalFare'] as Map<String, dynamic>?),
      requestedAt: d['requestedAt'] as Timestamp?,
      rating: (d['rating'] as num?)?.toInt(),
      driverInfo: DriverInfo.fromMap(d['driverInfo'] as Map<String, dynamic>?),
      payment: RidePayment.fromMap(d['payment'] as Map<String, dynamic>?),
    );
  }

  bool get isOpen => status == 'requested' ||
      status == 'accepted' ||
      status == 'arrived' ||
      status == 'in_progress';
}

/// Driver details the rider is allowed to see. Written onto the ride document
/// by the accept trigger — the rider app never reads the drivers collection,
/// which also holds phone numbers and live location.
class DriverInfo {
  final String name;
  final String vehicleLabel;
  final double rating;
  final int ratingCount;

  /// Present only while the ride is live; cleared when it finishes.
  final String? phone;

  const DriverInfo({
    required this.name,
    required this.vehicleLabel,
    required this.rating,
    required this.ratingCount,
    required this.phone,
  });

  static DriverInfo? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return DriverInfo(
      name: (m['name'] ?? 'Driver') as String,
      vehicleLabel: (m['vehicleLabel'] ?? '') as String,
      rating: ((m['rating'] ?? 0) as num).toDouble(),
      ratingCount: ((m['ratingCount'] ?? 0) as num).toInt(),
      phone: m['phone'] as String?,
    );
  }
}
