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
    );
  }

  bool get isOpen => status == 'requested' ||
      status == 'accepted' ||
      status == 'arrived' ||
      status == 'in_progress';
}

class DriverInfo {
  final String name;
  final String phone;
  final String vehicleLabel;
  final double rating;
  final int ratingCount;
  final GeoPoint? location;

  const DriverInfo({
    required this.name,
    required this.phone,
    required this.vehicleLabel,
    required this.rating,
    required this.ratingCount,
    required this.location,
  });

  factory DriverInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final v = (d['vehicle'] ?? {}) as Map<String, dynamic>;
    return DriverInfo(
      name: (d['name'] ?? 'Driver') as String,
      phone: (d['phone'] ?? '') as String,
      vehicleLabel:
          '${v['color'] ?? ''} ${v['make'] ?? ''} ${v['model'] ?? ''} · ${v['plate'] ?? ''}',
      rating: ((d['rating'] ?? 0) as num).toDouble(),
      ratingCount: ((d['ratingCount'] ?? 0) as num).toInt(),
      location: d['location'] as GeoPoint?,
    );
  }
}
