import 'package:flutter/material.dart';

import '../core/models.dart';
import '../services/auth_service.dart';
import '../services/driver_service.dart';
import '../services/notification_service.dart';
import '../services/ride_service.dart';
import 'active_ride_screen.dart';
import 'documents_screen.dart';
import 'earnings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init(
      onToken: (token) => DriverService.instance.saveFcmToken(token),
    );
  }

  @override
  void dispose() {
    DriverService.instance.dispose();
    super.dispose();
  }

  Future<void> _toggleOnline(DriverProfile profile) async {
    setState(() => _toggling = true);
    try {
      if (profile.isOnline) {
        await DriverService.instance.goOffline();
      } else {
        await DriverService.instance.goOnline();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DriverProfile>(
      stream: DriverService.instance.profileStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final profile = snapshot.data!;

        if (profile.approvalStatus != 'approved') {
          return _PendingScreen(profile: profile);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(profile.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.folder_outlined),
                tooltip: 'Documents',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.payments_outlined),
                tooltip: 'Earnings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EarningsScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
                onPressed: () async {
                  await DriverService.instance.goOffline();
                  await AuthService.instance.signOut();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _OnlineBanner(
                profile: profile,
                busy: _toggling,
                onToggle: () => _toggleOnline(profile),
              ),
              Expanded(
                child: StreamBuilder<Ride?>(
                  stream: RideService.instance.activeRide(),
                  builder: (context, activeSnap) {
                    final active = activeSnap.data;
                    if (active != null) {
                      return ActiveRidePanel(ride: active);
                    }
                    if (!profile.isOnline) {
                      return const Center(
                        child: Text('Go online to receive ride requests.'),
                      );
                    }
                    return const _OpenRequestsList();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OnlineBanner extends StatelessWidget {
  const _OnlineBanner({
    required this.profile,
    required this.busy,
    required this.onToggle,
  });

  final DriverProfile profile;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final online = profile.isOnline;
    return Material(
      color: online ? Colors.green.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              online ? Icons.wifi_tethering : Icons.wifi_tethering_off,
              color: online ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    online ? 'You are online' : 'You are offline',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    profile.vehicle.label,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: online,
              onChanged: busy ? null : (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenRequestsList extends StatelessWidget {
  const _OpenRequestsList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ride>>(
      stream: RideService.instance.openRequests(),
      builder: (context, snapshot) {
        final rides = snapshot.data ?? [];
        if (rides.isEmpty) {
          return const Center(child: Text('Waiting for ride requests…'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rides.length,
          itemBuilder: (context, i) {
            final ride = rides[i];
            final fare = ride.fareEstimate;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.hail),
                title: Text(ride.pickup.address,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('→ ${ride.dropoff.address}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (fare != null)
                      Text(
                        '${fare.currency} ${fare.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    Text('${ride.estimatedDistanceKm} km',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
                onTap: () async {
                  final ok = await RideService.instance.acceptRide(ride.id);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ride no longer available.'),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _PendingScreen extends StatelessWidget {
  const _PendingScreen({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final rejected = profile.approvalStatus == 'rejected';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                rejected ? Icons.cancel_outlined : Icons.hourglass_top,
                size: 64,
                color: rejected ? Colors.red : Colors.amber,
              ),
              const SizedBox(height: 16),
              Text(
                rejected
                    ? 'Your application was not approved.'
                    : 'Your application is under review.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                rejected
                    ? 'Please contact support for more information.'
                    : 'We\'ll notify you as soon as you\'re approved. '
                        'This screen updates automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              if (!rejected) ...[
                const SizedBox(height: 24),
                if (!profile.hasAllDocuments)
                  Text(
                    'Your documents are still incomplete — we can\'t review '
                    'your application until they\'re uploaded.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    profile.hasAllDocuments
                        ? 'Review documents'
                        : 'Upload documents',
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
