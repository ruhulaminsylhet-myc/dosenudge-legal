import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/models.dart';
import '../l10n/strings.dart';
import '../services/rider_service.dart';
import 'ride_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Strings.of(context);
    final dateFmt = DateFormat('d MMM yyyy, HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(t.rideHistory)),
      body: StreamBuilder<List<Ride>>(
        stream: RiderService.instance.history(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rides = snapshot.data!;
          if (rides.isEmpty) {
            return Center(child: Text(t.noRidesYet));
          }
          return ListView.separated(
            itemCount: rides.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final ride = rides[i];
              final fare = ride.finalFare ?? ride.fareEstimate;
              return ListTile(
                leading: Icon(
                  switch (ride.status) {
                    'completed' => Icons.check_circle_outline,
                    'cancelled' || 'expired' => Icons.cancel_outlined,
                    _ => Icons.local_taxi,
                  },
                  color: switch (ride.status) {
                    'completed' => Colors.green,
                    'cancelled' || 'expired' => Colors.red,
                    _ => Colors.blue,
                  },
                ),
                title: Text(ride.dropoff.address,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(ride.requestedAt != null
                    ? dateFmt.format(ride.requestedAt!.toDate())
                    : ''),
                trailing: Text(
                  fare?.label ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => RideScreen(rideId: ride.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
