import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import 'agent_dashboard_page.dart';

class AgentHistoryPage extends ConsumerWidget {
  const AgentHistoryPage({super.key});
  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => FutureBuilder<List<dynamic>>(
    future: ref.read(agentRepositoryProvider).history(),
    builder: (_, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final rows = snapshot.data!;
      return ListView(
        children: [
          const Text(
            'Mi historial',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          ...rows.map((raw) {
            final row = raw as Map;
            final date = DateTime.tryParse(
              row['last_message_at']?.toString() ?? '',
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(row['contact']),
                subtitle: Text(
                  'Enviados: ${row['sent_messages_count']} · Recibidos: ${row['received_messages_count']}\n${date == null ? 'Sin mensajes' : DateFormat('dd/MM/yyyy HH:mm').format(date)}',
                ),
                trailing: Chip(
                  label: Text(
                    row['status'] == 'closed' ? 'Cerrado' : 'Abierto',
                  ),
                ),
              ),
            );
          }),
        ],
      );
    },
  );
}
