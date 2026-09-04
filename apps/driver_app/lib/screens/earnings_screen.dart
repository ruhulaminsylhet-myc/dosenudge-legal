import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';
import '../services/driver_service.dart';
import '../services/ride_service.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: Column(
        children: [
          StreamBuilder<DriverProfile>(
            stream: DriverService.instance.profileStream(),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              if (profile == null || profile.payoutsEnabled) {
                return const SizedBox.shrink();
              }
              return const _PayoutSetupBanner();
            },
          ),
          const Expanded(child: _EarningsList()),
        ],
      ),
    );
  }
}

/// Until Stripe has verified the driver, card fares can't be routed to them —
/// riders are asked to pay cash instead, so this stays prominent.
class _PayoutSetupBanner extends StatefulWidget {
  const _PayoutSetupBanner();

  @override
  State<_PayoutSetupBanner> createState() => _PayoutSetupBannerState();
}

class _PayoutSetupBannerState extends State<_PayoutSetupBanner> {
  bool _busy = false;
  String? _error;

  Future<void> _startOnboarding() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await DriverService.instance.payoutOnboardingUrl();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      // Onboarding continues in the browser; check the outcome on return.
      await DriverService.instance.refreshPayoutStatus();
    } catch (_) {
      setState(() => _error = 'Could not open payout setup. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Set up payouts',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your bank details with Stripe so card fares reach you '
              'automatically. Until then riders have to pay you in cash.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _startOnboarding,
                child: Text(_busy ? 'Opening…' : 'Set up payouts'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsList extends StatelessWidget {
  const _EarningsList();

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM, HH:mm');

    return StreamBuilder<List<EarningsEntry>>(
      stream: RideService.instance.earnings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return const Center(child: Text('No completed trips yet.'));
        }

        final currency = entries.first.currency;
        final total = entries.fold<double>(0, (sum, e) => sum + e.netPayout);

        return Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Net earnings (last 50 trips)',
                      style: TextStyle(color: Colors.white70)),
                  Text(
                    '$currency ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  return ListTile(
                    leading: const Icon(Icons.check_circle_outline,
                        color: Colors.green),
                    title: Text(
                      '${e.currency} ${e.netPayout.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Fare ${e.grossFare.toStringAsFixed(2)} · '
                      'commission ${e.commission.toStringAsFixed(2)}',
                    ),
                    trailing: Text(
                      e.createdAt != null
                          ? dateFmt.format(e.createdAt!.toDate())
                          : '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
