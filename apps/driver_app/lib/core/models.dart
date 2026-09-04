import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String make;
  final String model;
  final String color;
  final String plate;
  final String type;

  const Vehicle({
    required this.make,
    required this.model,
    required this.color,
    required this.plate,
    this.type = 'standard',
  });

  factory Vehicle.fromMap(Map<String, dynamic>? m) => Vehicle(
        make: (m?['make'] ?? '') as String,
        model: (m?['model'] ?? '') as String,
        color: (m?['color'] ?? '') as String,
        plate: (m?['plate'] ?? '') as String,
        type: (m?['type'] ?? 'standard') as String,
      );

  Map<String, dynamic> toMap() => {
        'make': make,
        'model': model,
        'color': color,
        'plate': plate,
        'type': type,
      };

  String get label => '$color $make $model · $plate';
}

/// Which verification documents a driver must upload before approval.
enum DriverDocument {
  licence('licence', 'Driving licence'),
  insurance('insurance', 'Insurance certificate'),
  vehiclePhoto('vehiclePhoto', 'Vehicle photo');

  const DriverDocument(this.key, this.label);

  final String key;
  final String label;
}

class DriverProfile {
  final String id;
  final String name;
  final String phone;
  final String approvalStatus; // pending | approved | rejected
  final bool isOnline;
  final Vehicle vehicle;
  final double rating;
  final int ratingCount;
  final int totalRides;
  final double totalEarnings;

  /// Uploaded document download URLs, keyed by [DriverDocument.key].
  final Map<String, String> documents;

  const DriverProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.approvalStatus,
    required this.isOnline,
    required this.vehicle,
    required this.rating,
    required this.ratingCount,
    required this.totalRides,
    required this.totalEarnings,
    required this.documents,
  });

  bool get hasAllDocuments =>
      DriverDocument.values.every((d) => documents.containsKey(d.key));

  factory DriverProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DriverProfile(
      id: doc.id,
      name: (d['name'] ?? '') as String,
      phone: (d['phone'] ?? '') as String,
      approvalStatus: (d['approvalStatus'] ?? 'pending') as String,
      isOnline: (d['isOnline'] ?? false) as bool,
      vehicle: Vehicle.fromMap(d['vehicle'] as Map<String, dynamic>?),
      rating: ((d['rating'] ?? 0) as num).toDouble(),
      ratingCount: ((d['ratingCount'] ?? 0) as num).toInt(),
      totalRides: ((d['totalRides'] ?? 0) as num).toInt(),
      totalEarnings: ((d['totalEarnings'] ?? 0) as num).toDouble(),
      documents: ((d['documents'] ?? const <String, dynamic>{})
              as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String)),
    );
  }
}

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
  final double driverPayout;

  const Fare({
    required this.currency,
    required this.total,
    required this.driverPayout,
  });

  static Fare? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return Fare(
      currency: (m['currency'] ?? '') as String,
      total: ((m['total'] ?? 0) as num).toDouble(),
      driverPayout: ((m['driverPayout'] ?? 0) as num).toDouble(),
    );
  }
}

class Ride {
  final String id;
  final String riderId;
  final String riderName;
  final String? driverId;
  final String status;
  final RidePoint pickup;
  final RidePoint dropoff;
  final double estimatedDistanceKm;
  final Fare? fareEstimate;
  final Fare? finalFare;
  final Timestamp? requestedAt;

  const Ride({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.driverId,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.estimatedDistanceKm,
    required this.fareEstimate,
    required this.finalFare,
    required this.requestedAt,
  });

  factory Ride.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Ride(
      id: doc.id,
      riderId: (d['riderId'] ?? '') as String,
      riderName: (d['riderName'] ?? 'Rider') as String,
      driverId: d['driverId'] as String?,
      status: (d['status'] ?? 'requested') as String,
      pickup: RidePoint.fromMap(d['pickup'] as Map<String, dynamic>?),
      dropoff: RidePoint.fromMap(d['dropoff'] as Map<String, dynamic>?),
      estimatedDistanceKm:
          ((d['estimatedDistanceKm'] ?? 0) as num).toDouble(),
      fareEstimate: Fare.fromMap(d['fareEstimate'] as Map<String, dynamic>?),
      finalFare: Fare.fromMap(d['finalFare'] as Map<String, dynamic>?),
      requestedAt: d['requestedAt'] as Timestamp?,
    );
  }

  bool get isActive =>
      status == 'accepted' || status == 'arrived' || status == 'in_progress';
}

class EarningsEntry {
  final String id;
  final String currency;
  final double grossFare;
  final double commission;
  final double netPayout;
  final Timestamp? createdAt;

  const EarningsEntry({
    required this.id,
    required this.currency,
    required this.grossFare,
    required this.commission,
    required this.netPayout,
    required this.createdAt,
  });

  factory EarningsEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return EarningsEntry(
      id: doc.id,
      currency: (d['currency'] ?? '') as String,
      grossFare: ((d['grossFare'] ?? 0) as num).toDouble(),
      commission: ((d['commission'] ?? 0) as num).toDouble(),
      netPayout: ((d['netPayout'] ?? 0) as num).toDouble(),
      createdAt: d['createdAt'] as Timestamp?,
    );
  }
}
