import 'package:dio/dio.dart';

import 'api_client.dart';
import 'package:cloud_api_cc/data/models/task_model.dart';

/// Tareas asignadas al usuario autenticado.
class TasksApi {
  TasksApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  Future<Map<String, dynamic>> getTasks() async {
    final response = await _dio.get('/tareas');
    return response.data as Map<String, dynamic>;
  }

  Future<void> completeTask(int taskId) async {
    await _dio.patch('/tareas/$taskId/completar');
  }

  Future<Map<String, dynamic>?> getCachedTasks() {
    return _client.getTasksCache();
  }

  Future<void> cacheTasks(List<TaskModel> tasks) {
    return _client.saveTasksCache({
      'data': tasks.map((task) => task.toJson()).toList(),
    });
  }
}
