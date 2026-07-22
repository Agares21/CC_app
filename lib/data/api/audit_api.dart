import 'package:dio/dio.dart';
import 'api_client.dart';

/// Endpoints de auditoría.
class AuditApi {
  final ApiClient _client;
  AuditApi(this._client);
  Dio get _dio => _client.dio;

  Future<Map<String, dynamic>> getAuditLogs({String? category, String? dateFrom, String? dateTo}) async {
    final r = await _dio.get('/audit-logs', queryParameters: {
      if (category != null && category.isNotEmpty) 'category': category,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
    });
    return r.data;
  }
}
