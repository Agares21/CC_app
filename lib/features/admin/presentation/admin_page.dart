import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_repository.dart';

final adminRepositoryProvider = Provider(
  (ref) => AdminRepository(ref.watch(dioProvider)),
);

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});
  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 4, vsync: this);
  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TabBar(
        controller: tabs,
        isScrollable: true,
        labelColor: AppTheme.primary,
        tabs: const [
          Tab(text: 'Usuarios'),
          Tab(text: 'Horarios'),
          Tab(text: 'Crear tarea'),
          Tab(text: 'Seguimiento'),
        ],
      ),
      const SizedBox(height: 10),
      Expanded(
        child: TabBarView(
          controller: tabs,
          children: const [
            _UsersTab(),
            _SchedulesTab(),
            _CreateTaskTab(),
            _TrackingTab(),
          ],
        ),
      ),
    ],
  );
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();
  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  late Future<List<dynamic>> future = ref.read(adminRepositoryProvider).users();
  void reload() =>
      setState(() => future = ref.read(adminRepositoryProvider).users());
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: future,
    builder: (_, s) => !s.hasData
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _create(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Nuevo'),
            ),
            body: ListView(
              children: s.data!.map((raw) {
                final user = raw as Map;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _edit(context, user),
                    title: Text('${user['name']} ${user['last_name']}'),
                    subtitle: Text(user['email']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref
                            .read(adminRepositoryProvider)
                            .deleteUser(user['id']);
                        reload();
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
  );
  Future<void> _create(BuildContext context) async {
    final name = TextEditingController(),
        last = TextEditingController(),
        email = TextEditingController(),
        pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo agente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: last,
                decoration: const InputDecoration(labelText: 'Apellido'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(adminRepositoryProvider).createUser({
        'name': name.text,
        'last_name': last.text,
        'email': email.text,
        'password': pass.text,
        'password_confirmation': pass.text,
      });
      reload();
    }
  }

  Future<void> _edit(BuildContext context, Map user) async {
    final name = TextEditingController(text: user['name']);
    final last = TextEditingController(text: user['last_name']);
    final email = TextEditingController(text: user['email']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: last,
              decoration: const InputDecoration(labelText: 'Apellido'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(adminRepositoryProvider).updateUser(user['id'], {
        'name': name.text,
        'last_name': last.text,
        'email': email.text,
      });
      reload();
    }
  }
}

class _SchedulesTab extends ConsumerStatefulWidget {
  const _SchedulesTab();
  @override
  ConsumerState<_SchedulesTab> createState() => _SchedulesTabState();
}

class _SchedulesTabState extends ConsumerState<_SchedulesTab> {
  late Future<List<dynamic>> future = ref
      .read(adminRepositoryProvider)
      .schedules();
  void reload() =>
      setState(() => future = ref.read(adminRepositoryProvider).schedules());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: future,
    builder: (_, s) => !s.hasData
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: s.data!.map((raw) {
              final row = raw as Map;
              final shifts = row['shifts'] as List;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(row['user']['name']),
                  subtitle: Text('${shifts.length} turnos'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_calendar),
                    onPressed: () => _edit(context, row),
                  ),
                  children: shifts
                      .map(
                        (shift) => ListTile(
                          dense: true,
                          title: Text(_dayNames[shift['weekday']]),
                          trailing: Text(
                            '${shift['start_time']} – ${shift['end_time']}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            }).toList(),
          ),
  );

  Future<void> _edit(BuildContext context, Map row) async {
    final current = <int, Map>{
      for (final shift in row['shifts'] as List)
        shift['weekday'] as int: shift as Map,
    };
    final starts = List.generate(
      7,
      (i) => TextEditingController(text: current[i + 1]?['start_time'] ?? ''),
    );
    final ends = List.generate(
      7,
      (i) => TextEditingController(text: current[i + 1]?['end_time'] ?? ''),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Horario de ${row['user']['name']}'),
        content: SizedBox(
          width: 430,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 7,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 82, child: Text(_dayNames[i + 1])),
                  Expanded(
                    child: TextField(
                      controller: starts[i],
                      decoration: const InputDecoration(hintText: '09:00'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('–'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: ends[i],
                      decoration: const InputDecoration(hintText: '18:00'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final shifts = <Map<String, dynamic>>[];
      for (var i = 0; i < 7; i++) {
        if (starts[i].text.isNotEmpty && ends[i].text.isNotEmpty) {
          shifts.add({
            'weekday': i + 1,
            'start_time': starts[i].text,
            'end_time': ends[i].text,
          });
        }
      }
      await ref
          .read(adminRepositoryProvider)
          .saveSchedule(row['user']['id'], shifts);
      reload();
    }
  }
}

const _dayNames = [
  '',
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

class _CreateTaskTab extends ConsumerStatefulWidget {
  const _CreateTaskTab();
  @override
  ConsumerState<_CreateTaskTab> createState() => _CreateTaskTabState();
}

class _CreateTaskTabState extends ConsumerState<_CreateTaskTab> {
  final title = TextEditingController(), description = TextEditingController();
  final selected = <int>{};
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: ref.read(adminRepositoryProvider).users(),
    builder: (_, s) => !s.hasData
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 14),
              const Text(
                'Asignar agentes',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...s.data!
                  .where((u) => u['is_admin'] != true)
                  .map(
                    (u) => CheckboxListTile(
                      value: selected.contains(u['id']),
                      title: Text('${u['name']} ${u['last_name']}'),
                      subtitle: Text(u['email']),
                      onChanged: (v) => setState(
                        () => v == true
                            ? selected.add(u['id'])
                            : selected.remove(u['id']),
                      ),
                    ),
                  ),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(adminRepositoryProvider)
                      .createTask(
                        title.text,
                        description.text,
                        selected.toList(),
                      );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tarea creada.')),
                  );
                  title.clear();
                  description.clear();
                  setState(selected.clear);
                },
                child: const Text('Crear y asignar'),
              ),
            ],
          ),
  );
}

class _TrackingTab extends ConsumerWidget {
  const _TrackingTab();
  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => FutureBuilder<Map<String, dynamic>>(
    future: ref.read(adminRepositoryProvider).tracking(),
    builder: (_, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final tasks = s.data!['task_assignments'] as List,
          agents = s.data!['agent_activity'] as List;
      return ListView(
        children: [
          const Text(
            'Historial de tareas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
          ...tasks.map((raw) {
            final item = raw as Map;
            final done = item['status'] == 'completed';
            return Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                title: Text(item['titulo']),
                subtitle: Text(
                  '${item['user']['name']} · ${done ? 'Realizada' : 'Pendiente'}',
                ),
                trailing: Icon(
                  done ? Icons.check_circle : Icons.schedule,
                  color: done ? Colors.green : Colors.orange,
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          const Text(
            'Actividad de chats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
          ...agents.map((raw) {
            final a = raw as Map;
            final date = DateTime.tryParse(
              a['last_response_at']?.toString() ?? '',
            );
            return Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                title: Text(a['name']),
                subtitle: Text(
                  '${a['responses_count']} respuestas · ${a['chats_count']} chats',
                ),
                trailing: Text(
                  date == null
                      ? 'Sin actividad'
                      : DateFormat('dd/MM HH:mm').format(date),
                ),
              ),
            );
          }),
        ],
      );
    },
  );
}
