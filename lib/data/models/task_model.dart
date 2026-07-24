import 'package:equatable/equatable.dart';

enum TaskStatus { pending, completed }

class TaskAssignment extends Equatable {
  const TaskAssignment({
    required this.userId,
    required this.name,
    required this.lastName,
    required this.email,
    required this.status,
    required this.assignedAt,
    this.completedAt,
  });

  final int userId;
  final String name;
  final String lastName;
  final String email;
  final TaskStatus status;
  final String assignedAt;
  final String? completedAt;

  String get fullName => '$name $lastName'.trim();
  bool get completed => status == TaskStatus.completed;

  factory TaskAssignment.fromJson(Map<String, dynamic> json) {
    return TaskAssignment(
      userId: json['id'] as int,
      name: json['name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: json['status'] == 'completed'
          ? TaskStatus.completed
          : TaskStatus.pending,
      assignedAt: json['assigned_at'] as String? ?? '',
      completedAt: json['completed_at'] as String?,
    );
  }

  @override
  List<Object?> get props => [userId, status, assignedAt, completedAt];
}

class TaskModel extends Equatable {
  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    required this.assignments,
  });

  final int id;
  final String title;
  final String? description;
  final String createdAt;
  final List<TaskAssignment> assignments;

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as int,
      title: json['titulo'] as String? ?? '',
      description: json['descripcion'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      assignments: (json['usuarios'] as List<dynamic>? ?? const [])
          .map(
            (assignment) =>
                TaskAssignment.fromJson(assignment as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  TaskAssignment? assignmentFor(int userId) {
    for (final assignment in assignments) {
      if (assignment.userId == userId) return assignment;
    }
    return null;
  }

  @override
  List<Object?> get props => [id, title, description, assignments];
}
