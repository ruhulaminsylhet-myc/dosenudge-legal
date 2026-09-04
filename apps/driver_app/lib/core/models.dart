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
/// Labels live in the l10n strings so they can be translated.
enum DriverDocument {
  licence('licence', requiresExpiry: true),
  insurance('insurance', requiresExpiry: true),
  vehiclePhoto('vehiclePhoto', requiresExpiry: false);

  const DriverDocument(this.key, {required this.requiresExpiry});

  final String key;

  /// True where the law only accepts the document while it is in date, so the
  /// driver must tell us when it runs out. Mirrors EXPIRING_DOCUMENTS in
  /// functions/src/types.ts — the daily sweep uses the same list.
  final bool requiresExpiry;
}

/// One uploaded document: where it lives, and when it stops being valid.
class DriverDocumentEntry {
  final String url;

  /// Null for documents that never expire, e.g. a vehicle photo.
  final DateTime? expiresAt;

  const DriverDocumentEntry({required this.url, this.expiresAt});

  /// Stored as ISO yyyy-mm-dd so the server can compare dates without a
  /// timezone argument.
  static DriverDocumentEntry? fromValue(dynamic value) {
    if (value is String) return DriverDocumentEntry(url: value);
    if (value is! Map) return null;
    final url = value['url'];
    if (url is! String) return null;
    final raw = value['expiresAt'];
    return DriverDocumentEntry(
      url: url,
      expiresAt: raw is String ? DateTime.tryParse(raw) : null,
    );
  }

  /// Whole days until expiry; negative once past. Null if it never expires.
  int? get daysRemaining {
    if (expiresAt == null) return null;
    final today = DateTime.now();
    return DateTime(expiresAt!.year, expiresAt!.month, expiresAt!.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  bool get isExpired => (daysRemaining ?? 1) < 0;

  /// Close enough that the driver should already be renewing it.
  bool get isExpiringSoon {
    final days = daysRemaining;
    return days != null && days >= 0 && days <= 30;
  }
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

  /// Uploaded documents, keyed by [DriverDocument.key].
  final Map<String, DriverDocumentEntry> documents;

  /// True once Stripe has verified the driver and payouts can be sent.
  final bool payoutsEnabled;

  /// Set by the server when a required document lapsed and the driver was
  /// taken off the road, so the app can say why instead of showing a bare
  /// "under review".
  final bool expiryBlocked;

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
    required this.payoutsEnabled,
    required this.expiryBlocked,
  });

  /// Every document present, and every one that must carry an expiry date has
  /// one. A licence photo with no expiry can't be policed, so it doesn't count
  /// as complete.
  bool get hasAllDocuments => DriverDocument.values.every((d) {
        final entry = documents[d.key];
        return entry != null && (!d.requiresExpiry || entry.expiresAt != null);
      });

  /// Documents already past their date. Non-empty means the driver can't work.
  List<DriverDocument> get expiredDocuments => DriverDocument.values
      .where((d) => documents[d.key]?.isExpired ?? false)
      .toList();

  /// Documents inside the 30-day renewal window.
  List<DriverDocument> get expiringDocuments => DriverDocument.values
      .where((d) => documents[d.key]?.isExpiringSoon ?? false)
      .toList();

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
      documents: {
        for (final e in ((d['documents'] ?? const <String, dynamic>{})
                as Map<String, dynamic>)
            .entries)
          if (DriverDocumentEntry.fromValue(e.value) case final entry?)
            e.key: entry,
      },
      payoutsEnabled: (d['payoutsEnabled'] ?? false) as bool,
      expiryBlocked: (d['expiryBlocked'] ?? false) as bool,
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

  /// Present only while the ride is live; cleared when it finishes.
  final String? riderPhone;

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
    required this.riderPhone,
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
      riderPhone: d['riderPhone'] as String?,
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
