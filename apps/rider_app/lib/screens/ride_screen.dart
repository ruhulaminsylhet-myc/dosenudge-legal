import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';
import '../l10n/strings.dart';
import '../services/rider_service.dart';

class RideScreen extends StatelessWidget {
  const RideScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    final t = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.yourRide)),
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
                                ? t.finalFare
                                : t.estimatedFare),
                            Text(
                              (ride.finalFare ?? ride.fareEstimate)?.label ??
                                  t.calculating,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (ride.driverInfo != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(ride.driverInfo!.name),
                          subtitle: Text(ride.driverInfo!.vehicleLabel),
                          trailing: ride.driverInfo!.ratingCount > 0
                              ? Text(
                                  '${ride.driverInfo!.rating.toStringAsFixed(1)} ⭐')
                              : null,
                        ),
                        if (ride.driverInfo!.phone != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.phone),
                                label: Text(t.callDriver),
                                onPressed: () => launchUrl(Uri(
                                  scheme: 'tel',
                                  path: ride.driverInfo!.phone,
                                )),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (ride.status == 'completed' && ride.driverId != null) ...[
                  _PaymentCard(ride: ride),
                  _RatingCard(ride: ride),
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
                    child: Text(t.cancelRide),
                  ),
                if (!ride.isOpen)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.done),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Card payment for a finished trip. Checkout happens on Stripe's hosted page,
/// and only the webhook flips the ride to paid — returning from the browser
/// proves nothing on its own.
class _PaymentCard extends StatefulWidget {
  const _PaymentCard({required this.ride});

  final Ride ride;

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _busy = false;
  String? _error;

  Future<void> _pay() async {
    final t = Strings.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await RiderService.instance.checkoutUrl(widget.ride.id);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      // The commonest case is a driver who hasn't finished payout setup, and
      // the callable explains that in its message.
      setState(() => _error = t.cardUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Strings.of(context);
    final payment = widget.ride.payment;
    if (payment?.isPaid ?? false) {
      return Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Colors.green),
              const SizedBox(width: 8),
              Text(t.paidAmount(
                  '${payment!.currency} ${payment.amount.toStringAsFixed(2)}')),
            ],
          ),
        ),
      );
    }

    final fare = widget.ride.finalFare;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.payYourFare, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              payment?.status == 'failed' ? t.paymentFailed : t.payByCardOrCash,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.credit_card),
                label: Text(_busy ? t.opening : t.payByCard(fare?.label ?? '')),
                onPressed: _busy ? null : _pay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingCard extends StatefulWidget {
  const _RatingCard({required this.ride});

  final Ride ride;

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  int _selected = 0;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final t = Strings.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await RiderService.instance.rateRide(widget.ride.id, _selected);
      // The ride stream pushes the saved rating back, flipping this card to
      // its thank-you state.
    } catch (e) {
      setState(() => _error = t.ratingFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Strings.of(context);
    final existing = widget.ride.rating;
    if (existing != null) {
      return Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(t.ratedTrip(existing)),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.rateYourDriver,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final value = i + 1;
                return IconButton(
                  icon: Icon(
                    value <= _selected ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: _busy ? null : () => setState(() => _selected = value),
                );
              }),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_selected == 0 || _busy) ? null : _submit,
                child: Text(_busy ? t.saving : t.submitRating),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final t = Strings.of(context);
    final (icon, color, text) = switch (status) {
      'requested' => (Icons.search, Colors.amber, t.findingDriver),
      'accepted' => (Icons.directions_car, Colors.blue, t.driverOnWay),
      'arrived' => (Icons.hail, Colors.blue, t.driverArrived),
      'in_progress' => (Icons.route, Colors.green, t.tripInProgress),
      'completed' => (Icons.check_circle, Colors.green, t.tripCompleted),
      'cancelled' => (Icons.cancel, Colors.red, t.rideCancelled),
      'expired' => (Icons.timer_off, Colors.grey, t.noDriversFound),
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
