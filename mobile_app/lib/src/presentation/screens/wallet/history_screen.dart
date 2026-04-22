import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/wallet_controller.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body:
          wallet.loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: wallet.movements.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final m = wallet.movements[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${m.type}  Bs. ${m.amount.toStringAsFixed(2)}',
                      ),
                      subtitle: Text(
                        '${m.fromEmail ?? '-'} -> ${m.toEmail ?? '-'}\n${m.createdAt.toLocal()}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
    );
  }
}
