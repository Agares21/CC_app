import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/agent_repository.dart';

final agentRepositoryProvider = Provider(
  (ref) => AgentRepository(ref.watch(dioProvider)),
);

class AgentDashboardPage extends ConsumerStatefulWidget {
  const AgentDashboardPage({super.key});
  @override
  ConsumerState<AgentDashboardPage> createState() => _AgentDashboardPageState();
}

class _AgentDashboardPageState extends ConsumerState<AgentDashboardPage> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = ref.read(agentRepositoryProvider).dashboard();
  }

  void reload() =>
      setState(() => future = ref.read(agentRepositoryProvider).dashboard());

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: future,
    builder: (_, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final schedule = data['schedule'] as Map?;
      final tasks = data['tasks'] as List;
      final chats = data['chats'] as List;
      return RefreshIndicator(
        onRefresh: () async => reload(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const Text(
              'Mi panel de agente',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Mi horario',
              icon: Icons.calendar_month,
              child: schedule == null
                  ? const Text('No tienes horario asignado.')
                  : Column(
                      children: (schedule['shifts'] as List)
                          .map(
                            (s) => ListTile(
                              dense: true,
                              title: Text(_days[s['weekday'] as int]),
                              trailing: Text(
                                '${s['start_time']} – ${s['end_time']}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Mis tareas',
              icon: Icons.task_alt,
              child: tasks.isEmpty
                  ? const Text('No tienes tareas asignadas.')
                  : Column(
                      children: tasks.map((raw) {
                        final task = raw as Map;
                        final pivot = task['pivot'] as Map;
                        final done = pivot['status'] == 'completed';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(task['titulo']),
                          subtitle: task['descripcion'] == null
                              ? null
                              : Text(task['descripcion']),
                          trailing: done
                              ? const Chip(label: Text('Realizada'))
                              : TextButton(
                                  onPressed: () async {
                                    await ref
                                        .read(agentRepositoryProvider)
                                        .completeTask(task['id']);
                                    reload();
                                  },
                                  child: const Text('Completar'),
                                ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Chats disponibles',
              icon: Icons.chat_bubble_outline,
              child: Text(
                '${chats.length} conversaciones disponibles en la sección Chats.',
              ),
            ),
          ],
        ),
      );
    },
  );
}

const _days = [
  '',
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    ),
  );
}
