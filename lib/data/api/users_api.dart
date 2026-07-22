import 'package:dio/dio.dart';
import 'api_client.dart';

/// Endpoints CRUD de usuarios.
class UsersApi {
  final ApiClient _client;
  UsersApi(this._client);
  Dio get _dio => _client.dio;

  Future<Map<String, dynamic>> getUsers() async { final r = await _dio.get('/users'); return r.data; }
  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async { final r = await _dio.post('/users', data: data); return r.data; }
  Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> data) async { final r = await _dio.put('/users/$id', data: data); return r.data; }
  Future<void> deleteUser(int id) async { await _dio.delete('/users/$id'); }
  Future<Map<String, dynamic>> getRoles() async { final r = await _dio.get('/roles'); return r.data; }
}
