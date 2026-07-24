import 'package:dio/dio.dart';
import 'api_client.dart';
import 'package:cloud_api_cc/data/models/conversation_model.dart';

/// Endpoints de conversaciones.
class ConversationsApi {
  final ApiClient _client;
  ConversationsApi(this._client);
  Dio get _dio => _client.dio;

  /// Bandeja de chats.
  ///
  /// [perPage] la pagina (sin él la API devuelve la lista entera, que es lo que
  /// espera el panel web). [updatedSince] pide solo lo que cambió desde esa
  /// marca: es la forma barata de refrescar, usando el `meta.synced_at` que
  /// devolvió la llamada anterior.
  Future<Map<String, dynamic>> getConversations({
    bool archived = false,
    String? dateFrom,
    String? dateTo,
    int? perPage,
    int? page,
    String? updatedSince,
  }) async {
    final r = await _dio.get(
      '/conversations',
      queryParameters: {
        if (archived) 'archived': 1,
        'date_from': ?dateFrom,
        'date_to': ?dateTo,
        'per_page': ?perPage,
        'page': ?page,
        'updated_since': ?updatedSince,
      },
    );
    return r.data;
  }

  /// Detalle de un chat. [messagesLimit] trae solo los N mensajes más
  /// recientes; el resto se pide con [getMessages] al scrollear hacia arriba.
  Future<Map<String, dynamic>> getConversation(
    int id, {
    int? messagesLimit,
  }) async {
    final r = await _dio.get(
      '/conversations/$id',
      queryParameters: {'messages_limit': ?messagesLimit},
    );
    return r.data;
  }

  /// Historial hacia atrás. [before] es el id del mensaje más viejo que ya se
  /// tiene: llega en `messages_cursor` (detalle) o en `meta.next_cursor` (acá).
  Future<Map<String, dynamic>> getMessages(
    int conversationId, {
    int? before,
    int limit = 50,
  }) async {
    final r = await _dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {'limit': limit, 'before': ?before},
    );
    return r.data;
  }

  Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    String? body,
    String? mediaPath,
    String? mediaName,
  }) async {
    final formData = FormData();
    if (body != null && body.isNotEmpty) {
      formData.fields.add(MapEntry('body', body));
    }
    if (mediaPath != null) {
      formData.files.add(
        MapEntry(
          'media',
          await MultipartFile.fromFile(mediaPath, filename: mediaName),
        ),
      );
    }
    final r = await _dio.post(
      '/conversations/$conversationId/messages',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return r.data;
  }

  Future<Map<String, dynamic>?> getCachedConversations() {
    return _client.getConversationsCache();
  }

  Future<void> cacheConversations({
    required List<ConversationSummary> conversations,
    required int archivedCount,
  }) {
    return _client.saveConversationsCache({
      'data': conversations.map((item) => item.toJson()).toList(),
      'meta': {'archived_count': archivedCount},
    });
  }
}
