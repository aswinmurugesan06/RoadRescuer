import 'package:flutter/material.dart';
import '../../../core/constants/mock_data.dart';
import '../../../widgets/request_card_widget.dart';
import '../../../widgets/rr_loading.dart';

class ProviderHistoryScreen extends StatelessWidget {
  const ProviderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = MockData.providerServiceHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job History'),
        automaticallyImplyLeading: false,
      ),
      body: history.isEmpty
          ? const RREmptyState(
              icon: Icons.history_rounded,
              title: 'No Job History',
              subtitle: 'Completed assistance services will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                return RequestCardWidget(
                  request: history[i],
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Job #${history[i].id} details')),
                    );
                  },
                );
              },
            ),
    );
  }
}
