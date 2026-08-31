import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/models.dart';
import '../services/ride_service.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: StreamBuilder<List<EarningsEntry>>(
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
          final total =
              entries.fold<double>(0, (sum, e) => sum + e.netPayout);
          final dateFmt = DateFormat('d MMM, HH:mm');

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
      ),
    );
  }
}
