import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';
import '../l10n/strings.dart';
import '../services/ride_service.dart';

/// Panel shown on the home screen while a ride is in progress.
/// Navigation deep-links into Google Maps (no Maps API key needed for MVP).
class ActiveRidePanel extends StatelessWidget {
  const ActiveRidePanel({super.key, required this.ride});

  final Ride ride;

  Future<void> _navigateTo(RidePoint point) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${point.lat},${point.lng}&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = Strings.of(context);
    final (label, nextStatus, action) = switch (ride.status) {
      'accepted' => (
          t.headingToPickup,
          t.iHaveArrived,
          RideService.instance.markArrived
        ),
      'arrived' => (t.waitingForRider, t.startTrip, RideService.instance.startTrip),
      'in_progress' => (
          t.tripInProgress,
          t.completeTrip,
          RideService.instance.completeTrip
        ),
      _ => ('', '', null),
    };

    final target = ride.status == 'in_progress' ? ride.dropoff : ride.pickup;
    final fare = ride.finalFare ?? ride.fareEstimate;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 8),
                      Text(label,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const Divider(height: 24),
                  _AddressRow(icon: Icons.trip_origin, text: ride.pickup.address),
                  const SizedBox(height: 8),
                  _AddressRow(icon: Icons.place, text: ride.dropoff.address),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.riderName(ride.riderName)),
                      if (fare != null)
                        Text(
                          '${fare.currency} ${fare.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.navigation_outlined),
            label: Text(ride.status == 'in_progress'
                ? t.navigateToDropoff
                : t.navigateToPickup),
            onPressed: () => _navigateTo(target),
          ),
          const SizedBox(height: 8),
          if (action != null)
            FilledButton(
              onPressed: () => action(ride.id),
              child: Text(nextStatus),
            ),
          if (ride.status == 'accepted' || ride.status == 'arrived') ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(t.cancelRideQuestion),
                    content: Text(t.cancelWarning),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(t.keepRide),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(t.cancelRide),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await RideService.instance.cancelRide(ride.id);
                }
              },
              child: Text(t.cancelRide,
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
