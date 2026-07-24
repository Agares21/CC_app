import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_api_cc/data/models/task_model.dart';
import 'package:cloud_api_cc/data/models/user_model.dart';

void main() {
  test('identifica la tarea propia y su estado', () {
    final task = TaskModel.fromJson({
      'id': 41,
      'titulo': 'Responder seguimiento',
      'descripcion': 'Contactar al cliente.',
      'created_at': '2026-07-23T12:00:00Z',
      'usuarios': [
        {
          'id': 7,
          'name': 'Ana',
          'last_name': 'López',
          'email': 'ana@example.com',
          'status': 'pending',
          'assigned_at': '2026-07-23T12:00:00Z',
          'completed_at': null,
        },
      ],
    });

    expect(task.assignmentFor(7), isNotNull);
    expect(task.assignmentFor(7)!.completed, isFalse);
    expect(task.assignmentFor(8), isNull);
  });

  test('el usuario conserva la URL privada de su avatar', () {
    final user = UserModel.fromJson({
      'id': 7,
      'name': 'Ana',
      'last_name': 'López',
      'email': 'ana@example.com',
      'created_at': '2026-07-23T12:00:00Z',
      'avatar_url': '/api/profile/avatar?v=123',
      'role': {'id': 2, 'name': 'soporte'},
    });

    expect(user.avatarUrl, '/api/profile/avatar?v=123');
    expect(user.initials, 'AL');
  });
}
