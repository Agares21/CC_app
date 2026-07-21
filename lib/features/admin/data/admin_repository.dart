import 'package:dio/dio.dart';

class AdminRepository {
  const AdminRepository(this._dio);
  final Dio _dio;
  Future<List<dynamic>> users() async =>
      List<dynamic>.from((await _dio.get('/users')).data['data']);
  Future<void> createUser(Map<String, dynamic> data) =>
      _dio.post('/users', data: data);
  Future<void> updateUser(int id, Map<String, dynamic> data) =>
      _dio.put('/users/$id', data: data);
  Future<void> deleteUser(int id) => _dio.delete('/users/$id');
  Future<List<dynamic>> schedules() async =>
      List<dynamic>.from((await _dio.get('/schedules')).data['data']);
  Future<void> saveSchedule(int userId, List<Map<String, dynamic>> shifts) =>
      _dio.put('/users/$userId/schedule', data: {'shifts': shifts});
  Future<void> createTask(String title, String description, List<int> users) =>
      _dio.post(
        '/tareas',
        data: {'titulo': title, 'descripcion': description, 'usuarios': users},
      );
  Future<Map<String, dynamic>> tracking() async => Map<String, dynamic>.from(
    (await _dio.get('/admin/seguimiento')).data['data'],
  );
}
