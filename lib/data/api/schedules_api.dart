import 'package:dio/dio.dart';
import 'api_client.dart';

/// Endpoints de horarios.
class SchedulesApi {
  final ApiClient _client;
  SchedulesApi(this._client);
  Dio get _dio => _client.dio;

  Future<Map<String, dynamic>> getSchedules() async { final r = await _dio.get('/schedules'); return r.data; }

  Future<Map<String, dynamic>> updateSchedule({required int userId, required List<Map<String, dynamic>> shifts}) async {
    final r = await _dio.put('/users/$userId/schedule', data: {'shifts': shifts});
    return r.data;
  }
}
