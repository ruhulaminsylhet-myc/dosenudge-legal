import 'package:flutter/material.dart';

import '../core/models.dart';
import '../services/rider_service.dart';

class RideScreen extends StatelessWidget {
  const RideScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your ride')),
      body: StreamBuilder<Ride>(
        stream: RiderService.instance.rideStream(rideId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ride = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusHeader(status: ride.status),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.trip_origin,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text(ride.pickup.address)),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.place, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text(ride.dropoff.address)),
                        ]),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(ride.finalFare != null
                                ? 'Final fare'
                                : 'Estimated fare'),
                            Text(
                              (ride.finalFare ?? ride.fareEstimate)?.label ??
                                  'Calculating…',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (ride.driverId != null) ...[
                  const SizedBox(height: 12),
                  StreamBuilder<DriverInfo>(
                    stream:
                        RiderService.instance.driverStream(ride.driverId!),
                    builder: (context, driverSnap) {
                      final driver = driverSnap.data;
                      if (driver == null) return const SizedBox.shrink();
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                              child: Icon(Icons.person)),
                          title: Text(driver.name),
                          subtitle: Text(driver.vehicleLabel),
                          trailing: driver.ratingCount > 0
                              ? Text('${driver.rating.toStringAsFixed(1)} ⭐')
                              : null,
                        ),
                      );
                    },
                  ),
                ],
                const Spacer(),
                if (ride.status == 'requested' ||
                    ride.status == 'accepted' ||
                    ride.status == 'arrived')
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red),
                    onPressed: () async {
                      await RiderService.instance.cancelRide(ride.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Cancel ride'),
                  ),
                if (!ride.isOpen)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (status) {
      'requested' => (Icons.search, Colors.amber, 'Finding you a driver…'),
      'accepted' => (Icons.directions_car, Colors.blue, 'Driver is on the way'),
      'arrived' => (Icons.hail, Colors.blue, 'Your driver has arrived'),
      'in_progress' => (Icons.route, Colors.green, 'Trip in progress'),
      'completed' => (Icons.check_circle, Colors.green, 'Trip completed'),
      'cancelled' => (Icons.cancel, Colors.red, 'Ride cancelled'),
      'expired' => (Icons.timer_off, Colors.grey, 'No drivers found'),
      _ => (Icons.info, Colors.grey, status),
    };
    return Row(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 12),
        Text(text, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
