import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/models/conversation_model.dart';

/// Tiempo real de los chats vía Pusher.
///
/// Escucha el canal privado de la conversación abierta y emite los mensajes que
/// el backend transmite (evento `message.created`), para que aparezcan al
/// instante sin esperar al polleo, que queda como respaldo.
///
/// Las credenciales llegan por --dart-define (igual que la URL del backend):
///   flutter run --dart-define=PUSHER_APP_KEY=... --dart-define=PUSHER_APP_CLUSTER=sa1
/// Sin ellas, connect() no hace nada y la app sigue andando solo con el polleo.
class RealtimeService {
  RealtimeService({required ApiClient client}) : _client = client;

  final ApiClient _client;
  final _pusher = PusherChannelsFlutter.getInstance();
  final _messages = StreamController<ChatMessage>.broadcast();

  bool _available = false;
  int? _currentConversation;

  static const _key = String.fromEnvironment('PUSHER_APP_KEY');
  static const _cluster = String.fromEnvironment(
    'PUSHER_APP_CLUSTER',
    defaultValue: 'sa1',
  );

  /// Mensajes que llegan por el canal de la conversación abierta.
  Stream<ChatMessage> get onMessage => _messages.stream;

  /// Conecta a Pusher. Se llama al iniciar sesión (como el registro de push).
  Future<void> connect() async {
    if (_available || _key.isEmpty) return;

    try {
      await _pusher.init(
        apiKey: _key,
        cluster: _cluster,
        onEvent: _onEvent,
        onAuthorizer: _authorize,
      );
      await _pusher.connect();
      _available = true;
    } catch (e) {
      debugPrint('Realtime: no se pudo conectar, sigue el polleo. $e');
    }
  }

  /// Autoriza el canal privado contra /broadcasting/auth. Va con el Bearer que
  /// el interceptor de Dio agrega solo; el endpoint vive en la raíz del dominio,
  /// no bajo /api/v1, por eso se arma la URL absoluta.
  Future<dynamic> _authorize(
    String channelName,
    String socketId,
    dynamic options,
  ) async {
    final res = await _client.dio.post(
      _client.absoluteUrl('/broadcasting/auth'),
      data: {'socket_id': socketId, 'channel_name': channelName},
    );

    return res.data;
  }

  void _onEvent(PusherEvent event) {
    if (event.eventName != 'message.created') return;

    try {
      final raw = event.data;
      final json = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      _messages.add(ChatMessage.fromJson(json));
    } catch (e) {
      debugPrint('Realtime: no se pudo leer el mensaje. $e');
    }
  }

  /// Escucha una conversación (deja de escuchar la anterior). Se llama al abrir
  /// un chat; sólo se recibe tiempo real del chat que el agente está mirando.
  Future<void> subscribeConversation(int conversationId) async {
    if (!_available || _currentConversation == conversationId) return;

    await unsubscribeCurrent();
    _currentConversation = conversationId;

    try {
      // El prefijo private- lo exige el protocolo de Pusher para canales
      // privados; el backend lo define como "conversation.{id}".
      await _pusher.subscribe(channelName: 'private-conversation.$conversationId');
    } catch (e) {
      debugPrint('Realtime: no se pudo suscribir a $conversationId. $e');
    }
  }

  Future<void> unsubscribeCurrent() async {
    final id = _currentConversation;
    _currentConversation = null;
    if (!_available || id == null) return;

    try {
      await _pusher.unsubscribe(channelName: 'private-conversation.$id');
    } catch (_) {}
  }

  /// Se llama al cerrar sesión.
  Future<void> disconnect() async {
    _currentConversation = null;
    if (!_available) return;
    _available = false;

    try {
      await _pusher.disconnect();
    } catch (_) {}
  }

  void dispose() {
    _messages.close();
  }
}
