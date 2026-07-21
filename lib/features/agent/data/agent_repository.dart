import 'package:dio/dio.dart';

class AgentRepository {
  const AgentRepository(this._dio);
  final Dio _dio;
  Future<Map<String, dynamic>> dashboard() async => Map<String, dynamic>.from(
    (await _dio.get('/agente/resumen')).data['data'],
  );
  Future<List<dynamic>> history() async =>
      List<dynamic>.from((await _dio.get('/agente/historial')).data['data']);
  Future<void> completeTask(int id) =>
      _dio.patch('/agente/tareas/$id/completar');
}
