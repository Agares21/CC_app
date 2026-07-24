import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/core/theme/app_text_styles.dart';
import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/api/tasks_api.dart';
import 'package:cloud_api_cc/data/models/task_model.dart';
import 'package:cloud_api_cc/data/models/user_model.dart';
import 'package:cloud_api_cc/presentation/bloc/auth/auth_bloc.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late final TasksApi _api;
  var _tasks = <TaskModel>[];
  var _loading = true;
  String? _error;
  int? _completingId;

  UserModel? get _user {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.user : null;
  }

  @override
  void initState() {
    super.initState();
    _api = TasksApi(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await _api.getTasks();
      final tasks = (response['data'] as List<dynamic>? ?? const [])
          .map((task) => TaskModel.fromJson(task as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar las tareas.';
      });
    }
  }

  Future<void> _complete(TaskModel task) async {
    setState(() => _completingId = task.id);
    try {
      await _api.completeTask(task.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea marcada como realizada.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la tarea.')),
      );
    } finally {
      if (mounted) setState(() => _completingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const SizedBox.shrink();

    final assignments = _tasks
        .expand((task) => task.assignments.map((item) => (task, item)))
        .toList();
    final completed = assignments.where((item) => item.$2.completed).length;
    final pending = assignments.length - completed;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tareas', style: AppTextStyles.headingMd),
                  const SizedBox(height: 2),
                  Text(
                    user.isAdmin
                        ? 'Seguimiento de las tareas del equipo'
                        : 'Actividades asignadas a tu cuenta',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _Summary(
                          label: 'Asignadas',
                          value: assignments.length,
                          icon: Icons.assignment_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Summary(
                          label: 'Pendientes',
                          value: pending,
                          icon: Icons.schedule_outlined,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Summary(
                          label: 'Realizadas',
                          value: completed,
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else if (_tasks.isEmpty)
            const _EmptyTasks()
          else if (user.isAdmin)
            ...assignments.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AdminAssignmentCard(
                  task: entry.$1,
                  assignment: entry.$2,
                ),
              ),
            )
          else
            ..._tasks.map((task) {
              final assignment = task.assignmentFor(user.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskCard(
                  task: task,
                  assignment: assignment,
                  completing: _completingId == task.id,
                  onComplete: assignment == null || assignment.completed
                      ? null
                      : () => _complete(task),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.brand,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.captionXs,
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.assignment,
    required this.completing,
    required this.onComplete,
  });

  final TaskModel task;
  final TaskAssignment? assignment;
  final bool completing;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = assignment?.completed ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(task.title, style: AppTextStyles.headingSm),
                ),
                const SizedBox(width: 8),
                _StatusBadge(completed: isCompleted),
              ],
            ),
            if (task.description?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Text(task.description!, style: AppTextStyles.bodySm),
            ],
            const SizedBox(height: 12),
            Text(
              'Asignada ${_formatDate(assignment?.assignedAt ?? task.createdAt)}',
              style: AppTextStyles.caption,
            ),
            if (isCompleted) ...[
              const SizedBox(height: 4),
              Text(
                'Realizada ${_formatDate(assignment?.completedAt)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.success),
              ),
            ] else ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: completing ? null : onComplete,
                icon: completing
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  completing ? 'Actualizando…' : 'Marcar como realizada',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminAssignmentCard extends StatelessWidget {
  const _AdminAssignmentCard({required this.task, required this.assignment});

  final TaskModel task;
  final TaskAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(task.title, style: AppTextStyles.headingSm),
                ),
                _StatusBadge(completed: assignment.completed),
              ],
            ),
            if (task.description?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(task.description!, style: AppTextStyles.bodySm),
            ],
            const Divider(height: 24),
            Text(assignment.fullName, style: AppTextStyles.label),
            Text(assignment.email, style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Text(
              'Asignada ${_formatDate(assignment.assignedAt)}',
              style: AppTextStyles.caption,
            ),
            if (assignment.completed)
              Text(
                'Realizada ${_formatDate(assignment.completedAt)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.success),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppColors.success : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        completed ? 'Realizada' : 'Pendiente',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Column(
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 46,
              color: AppColors.mutedForeground.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text('No tienes tareas asignadas', style: AppTextStyles.headingSm),
            const SizedBox(height: 4),
            Text(
              'Cuando te asignen una actividad aparecerá aquí.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.destructive),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.bodySm),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

String _formatDate(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return '—';
  return DateFormat('dd/MM/yyyy, HH:mm').format(parsed.toLocal());
}
