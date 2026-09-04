import 'package:flutter/material.dart';

import '../core/models.dart';
import '../l10n/strings.dart';
import '../services/rider_service.dart';
import 'history_screen.dart';
import 'ride_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  RidePoint? _pickupPoint;
  Fare? _estimate;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    RiderService.instance.registerPushToken();
  }

  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final t = Strings.of(context);
    setState(() => _busy = true);
    try {
      final point = await RiderService.instance.currentLocationPoint();
      setState(() {
        _pickupPoint = point;
        _pickup.text = point.address;
        _error = null;
      });
    } catch (_) {
      setState(() => _error = t.somethingWentWrong);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<(RidePoint, RidePoint)?> _resolvePoints(Strings t) async {
    final pickupText = _pickup.text.trim();
    final dropoffText = _dropoff.text.trim();
    if (pickupText.isEmpty || dropoffText.isEmpty) {
      setState(() => _error = t.enterBothAddresses);
      return null;
    }
    final pickup = (_pickupPoint != null && _pickupPoint!.address == pickupText)
        ? _pickupPoint!
        : await RiderService.instance.geocodeAddress(pickupText);
    final dropoff = await RiderService.instance.geocodeAddress(dropoffText);
    return (pickup, dropoff);
  }

  Future<void> _getEstimate() async {
    final t = Strings.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _estimate = null;
    });
    try {
      final points = await _resolvePoints(t);
      if (points == null) return;
      final data = await RiderService.instance.fareEstimate(points.$1, points.$2);
      final fare = Map<String, dynamic>.from(data['fare'] as Map);
      setState(() => _estimate = Fare(
            currency: fare['currency'] as String,
            total: (fare['total'] as num).toDouble(),
          ));
    } catch (e) {
      setState(() => _error = t.couldNotEstimate);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _requestRide() async {
    final t = Strings.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final points = await _resolvePoints(t);
      if (points == null) return;
      final name = await RiderService.instance.displayName();
      final rideId = await RiderService.instance.requestRide(
        pickup: points.$1,
        dropoff: points.$2,
        riderName: name,
      );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RideScreen(rideId: rideId)),
        );
      }
    } catch (e) {
      setState(() => _error = t.couldNotRequest);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.bookATaxi),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: t.rideHistory,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => RiderService.instance.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Resume banner if a ride is already underway.
            StreamBuilder<Ride?>(
              stream: RiderService.instance.openRide(),
              builder: (context, snapshot) {
                final ride = snapshot.data;
                if (ride == null) return const SizedBox.shrink();
                return Material(
                  color: Colors.green.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.local_taxi, color: Colors.green),
                    title: Text(t.rideInProgress),
                    subtitle: Text(ride.status.replaceAll('_', ' ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => RideScreen(rideId: ride.id)),
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _pickup,
                      decoration: InputDecoration(
                        labelText: t.pickupAddress,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.trip_origin),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.my_location),
                          tooltip: t.useCurrentLocation,
                          onPressed: _busy ? null : _useCurrentLocation,
                        ),
                      ),
                      onChanged: (_) => setState(() => _estimate = null),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dropoff,
                      decoration: InputDecoration(
                        labelText: t.dropoffAddress,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.place),
                      ),
                      onChanged: (_) => setState(() => _estimate = null),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    if (_estimate != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.estimatedFare),
                              Text(
                                _estimate!.label,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: _busy ? null : _getEstimate,
                      child: Text(t.getFareEstimate),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy ? null : _requestRide,
                      child: Text(_busy ? t.pleaseWait : t.requestTaxi),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
