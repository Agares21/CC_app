import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_api_cc/core/realtime/realtime_service.dart';
import 'package:cloud_api_cc/data/api/conversations_api.dart';
import 'package:cloud_api_cc/data/models/conversation_model.dart';

abstract class ChatsEvent extends Equatable {
  const ChatsEvent();
  @override
  List<Object?> get props => [];
}

class ChatsLoadRequested extends ChatsEvent {}

class ChatsRefreshSilent extends ChatsEvent {
  const ChatsRefreshSilent({this.forceList = false});

  final bool forceList;

  @override
  List<Object?> get props => [forceList];
}

class ChatsSelectConversation extends ChatsEvent {
  final int conversationId;
  const ChatsSelectConversation(this.conversationId);
  @override
  List<Object?> get props => [conversationId];
}

class ChatsSendMessage extends ChatsEvent {
  final String? body;
  final String? mediaPath;
  final String? mediaName;
  const ChatsSendMessage({this.body, this.mediaPath, this.mediaName});
  @override
  List<Object?> get props => [body, mediaPath];
}

class ChatsBackToList extends ChatsEvent {}

class ChatsDismissTaken extends ChatsEvent {}

/// Un mensaje llegó por el canal de tiempo real (Pusher) del chat abierto.
class ChatsRealtimeMessage extends ChatsEvent {
  const ChatsRealtimeMessage(this.message);

  final ChatMessage message;

  @override
  List<Object?> get props => [message.id, message.status];
}

class ChatsState extends Equatable {
  final List<ConversationSummary> conversations;
  final int archivedCount;
  final bool loadingList;
  final int? selectedId;
  final ConversationDetail? detail;
  final bool loadingDetail;
  final bool sending;
  final bool chatTaken;
  final String? error;
  final String? sendNotice;
  final int sendRevision;
  final bool restoreLastMessage;

  const ChatsState({
    this.conversations = const [],
    this.archivedCount = 0,
    this.loadingList = false,
    this.selectedId,
    this.detail,
    this.loadingDetail = false,
    this.sending = false,
    this.chatTaken = false,
    this.error,
    this.sendNotice,
    this.sendRevision = 0,
    this.restoreLastMessage = false,
  });

  ChatsState copyWith({
    List<ConversationSummary>? conversations,
    int? archivedCount,
    bool? loadingList,
    int? selectedId,
    ConversationDetail? detail,
    bool? loadingDetail,
    bool? sending,
    bool? chatTaken,
    String? error,
    String? sendNotice,
    int? sendRevision,
    bool? restoreLastMessage,
    bool clearSelectedId = false,
    bool clearDetail = false,
    bool clearError = false,
    bool clearSendNotice = false,
  }) {
    return ChatsState(
      conversations: conversations ?? this.conversations,
      archivedCount: archivedCount ?? this.archivedCount,
      loadingList: loadingList ?? this.loadingList,
      selectedId: clearSelectedId ? null : (selectedId ?? this.selectedId),
      detail: clearDetail ? null : (detail ?? this.detail),
      loadingDetail: loadingDetail ?? this.loadingDetail,
      sending: sending ?? this.sending,
      chatTaken: chatTaken ?? this.chatTaken,
      error: clearError ? null : (error ?? this.error),
      sendNotice: clearSendNotice ? null : (sendNotice ?? this.sendNotice),
      sendRevision: sendRevision ?? this.sendRevision,
      restoreLastMessage: restoreLastMessage ?? this.restoreLastMessage,
    );
  }

  @override
  List<Object?> get props => [
    conversations,
    archivedCount,
    loadingList,
    selectedId,
    detail,
    loadingDetail,
    sending,
    chatTaken,
    error,
    sendNotice,
    sendRevision,
    restoreLastMessage,
  ];
}

/// Gestiona la bandeja de chats y el hilo activo.
class ChatsBloc extends Bloc<ChatsEvent, ChatsState> {
  final ConversationsApi _api;
  final RealtimeService? _realtime;
  StreamSubscription<ChatMessage>? _realtimeSub;
  Timer? _pollTimer;
  // Mientras no haya sockets, una sincronización moderada mantiene la app al
  // día sin ejecutar dos consultas cada cuatro segundos indefinidamente.
  static const _pollDuration = Duration(seconds: 15);

  // El polleo pide sólo lo que cambió, no la bandeja entera. `synced_at` viene
  // en la respuesta y se reenvía como `updated_since` en la siguiente vuelta.
  String? _syncedAt;

  // Con un chat abierto, el polleo trae sólo los últimos N mensajes y los
  // fusiona con el hilo ya cargado, en vez de rebajar la conversación completa.
  static const _messagesPollLimit = 40;

  ChatsBloc({required ConversationsApi api, RealtimeService? realtime})
    : _api = api,
      _realtime = realtime,
      super(const ChatsState()) {
    on<ChatsLoadRequested>(_onLoad);
    on<ChatsRefreshSilent>(_onRefreshSilent);
    on<ChatsSelectConversation>(_onSelect);
    on<ChatsSendMessage>(_onSendMessage);
    on<ChatsBackToList>(_onBackToList);
    on<ChatsDismissTaken>(_onDismissTaken);
    on<ChatsRealtimeMessage>(_onRealtimeMessage);

    // Los mensajes que llegan por Pusher se procesan como un evento más del
    // bloc, para que la fusión y el estado vivan en un solo lugar.
    _realtimeSub = _realtime?.onMessage.listen(
      (message) => add(ChatsRealtimeMessage(message)),
    );
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      _pollDuration,
      (_) => add(ChatsRefreshSilent()),
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _onLoad(
    ChatsLoadRequested event,
    Emitter<ChatsState> emit,
  ) async {
    // El bloc vive durante toda la sesión. Al volver desde Tareas o Perfil se
    // muestra lo que ya está en memoria SIN pedir nada: el polleo periódico
    // (que la página reinicia al montarse) se encarga de traer novedades.
    if (state.conversations.isNotEmpty) {
      emit(state.copyWith(loadingList: false, clearError: true));
      return;
    }

    final cached = await _api.getCachedConversations();
    if (cached != null) {
      final list = _parseConversations(cached);
      if (list.isNotEmpty) {
        emit(
          state.copyWith(
            conversations: list,
            archivedCount: _archivedCount(cached),
            loadingList: false,
            clearError: true,
          ),
        );
      }
    }

    if (state.conversations.isEmpty) {
      emit(state.copyWith(loadingList: true, clearError: true));
    }
    try {
      final data = await _api.getConversations();
      _syncedAt = _syncedAtFrom(data);
      final list = _mergeServerList(
        _parseConversations(data),
        state.conversations,
      );
      final archivedCount = _archivedCount(data);
      emit(
        state.copyWith(
          conversations: list,
          archivedCount: archivedCount,
          loadingList: false,
        ),
      );
      await _cacheConversations(list, archivedCount);
    } catch (_) {
      emit(
        state.copyWith(
          loadingList: false,
          error: 'No se pudieron cargar las conversaciones.',
        ),
      );
    }
  }

  Future<void> _onRefreshSilent(
    ChatsRefreshSilent event,
    Emitter<ChatsState> emit,
  ) async {
    if (state.sending) return;

    try {
      final selectedId = state.selectedId;
      if (selectedId != null && !event.forceList) {
        // Chat abierto: sólo los últimos mensajes (no el hilo entero) y se
        // fusionan con lo ya cargado por id, conservando el historial y
        // actualizando el estado (enviado → entregado → leído).
        final d = await _api.getConversation(
          selectedId,
          messagesLimit: _messagesPollLimit,
        );
        final incoming = ConversationDetail.fromJson(
          d['data'] as Map<String, dynamic>,
        );
        final current = state.detail;
        final messages = current != null && current.id == selectedId
            ? _mergeMessages(current.messages, incoming.messages)
            : incoming.messages;
        final detail = incoming.copyWith(messages: messages);
        final conversations = _upsertConversation(state.conversations, detail);
        emit(state.copyWith(conversations: conversations, detail: detail));
        await _cacheConversations(conversations, state.archivedCount);
        return;
      }

      // Bandeja: en el polleo se piden sólo los chats que cambiaron desde la
      // última marca (delta); un refresco forzado (volver a la lista, arranque)
      // pide la lista completa para reconciliar los que ya no están activos.
      final useDelta = !event.forceList && _syncedAt != null;
      final data = await _api.getConversations(
        updatedSince: useDelta ? _syncedAt : null,
      );
      _syncedAt = _syncedAtFrom(data) ?? _syncedAt;

      final incoming = _parseConversations(data);
      final list = useDelta
          ? _applyDelta(state.conversations, incoming)
          : _mergeServerList(incoming, state.conversations);
      final archivedCount = _archivedCount(data);
      emit(state.copyWith(conversations: list, archivedCount: archivedCount));
      await _cacheConversations(list, archivedCount);
    } catch (_) {}
  }

  Future<void> _onSelect(
    ChatsSelectConversation event,
    Emitter<ChatsState> emit,
  ) async {
    // Tiempo real del chat que se abre: los mensajes nuevos llegan por Pusher.
    _realtime?.subscribeConversation(event.conversationId);

    emit(
      state.copyWith(
        selectedId: event.conversationId,
        loadingDetail: true,
        clearDetail: true,
        chatTaken: false,
        clearError: true,
      ),
    );
    try {
      final data = await _api.getConversation(event.conversationId);
      final detail = ConversationDetail.fromJson(
        data['data'] as Map<String, dynamic>,
      );
      emit(
        state.copyWith(
          conversations: _upsertConversation(state.conversations, detail),
          detail: detail,
          loadingDetail: false,
        ),
      );
      await _cacheConversations(state.conversations, state.archivedCount);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 409) {
        emit(
          state.copyWith(
            loadingDetail: false,
            chatTaken: true,
            clearSelectedId: true,
            clearDetail: true,
            clearError: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          loadingDetail: false,
          error: 'No se pudo abrir la conversación.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loadingDetail: false,
          error: 'No se pudo abrir la conversación.',
        ),
      );
    }
  }

  Future<void> _onSendMessage(
    ChatsSendMessage event,
    Emitter<ChatsState> emit,
  ) async {
    final conversationId = state.selectedId;
    final currentDetail = state.detail;
    final body = event.body?.trim();
    if (conversationId == null || currentDetail == null) return;

    final temporaryId = -DateTime.now().microsecondsSinceEpoch;
    final now = DateTime.now().toUtc().toIso8601String();
    final optimisticMessage = ChatMessage(
      id: temporaryId,
      direction: 'outbound',
      type: event.mediaPath == null ? 'text' : 'media',
      body: body,
      status: 'pending',
      sentAt: now,
      createdAt: now,
      media: const [],
    );
    final optimisticDetail = currentDetail.copyWith(
      messages: [...currentDetail.messages, optimisticMessage],
      preview: body,
      lastMessageAt: now,
    );
    final optimisticList = _upsertConversation(
      state.conversations,
      optimisticDetail,
    );

    emit(
      state.copyWith(
        conversations: optimisticList,
        detail: optimisticDetail,
        sending: true,
        restoreLastMessage: false,
        clearSendNotice: true,
      ),
    );
    await _cacheConversations(optimisticList, state.archivedCount);

    try {
      final response = await _api.sendMessage(
        conversationId: conversationId,
        body: body,
        mediaPath: event.mediaPath,
        mediaName: event.mediaName,
      );
      final message = ChatMessage.fromJson(
        response['data'] as Map<String, dynamic>,
      );
      final messages = optimisticDetail.messages
          .map((item) => item.id == temporaryId ? message : item)
          .toList();
      final lastMessageAt = message.sentAt ?? message.createdAt;
      final detail = optimisticDetail.copyWith(
        messages: messages,
        preview: message.body ?? body,
        lastMessageAt: lastMessageAt,
      );
      final conversations = _upsertConversation(state.conversations, detail);
      final deliveryFailed = message.status == 'failed';
      emit(
        state.copyWith(
          conversations: conversations,
          detail: state.selectedId == conversationId ? detail : null,
          sending: false,
          sendNotice: deliveryFailed
              ? 'El mensaje quedó guardado, pero WhatsApp rechazó la entrega. Revisa la configuración del servidor.'
              : null,
          clearSendNotice: !deliveryFailed,
          sendRevision: state.sendRevision + 1,
          restoreLastMessage: false,
        ),
      );
      await _cacheConversations(conversations, state.archivedCount);
    } catch (error) {
      final status = error is DioException ? error.response?.statusCode : null;

      // El chat dejó de ser suyo mientras escribía. Es la misma situación que
      // al abrirlo (_onSelectConversation ya la resuelve así): la vista
      // dedicada explica qué pasó y lo devuelve a la bandeja, en vez de
      // dejarlo atrapado en un chat muerto insistiendo con "enviar" contra un
      // aviso que se desvanece. Se repone el resumen previo al optimista para
      // que la bandeja no muestre como último mensaje uno que nunca salió.
      if (status == 404 || status == 409) {
        final conversations = _upsertConversation(
          state.conversations,
          currentDetail,
        );
        emit(
          state.copyWith(
            conversations: conversations,
            sending: false,
            chatTaken: true,
            clearSelectedId: true,
            clearDetail: true,
            clearError: true,
            clearSendNotice: true,
            sendRevision: state.sendRevision + 1,
            restoreLastMessage: false,
          ),
        );
        await _cacheConversations(conversations, state.archivedCount);

        return;
      }

      final detail = state.detail;
      final cleanedDetail = detail?.id == conversationId
          ? detail!.copyWith(
              messages: detail.messages
                  .where((item) => item.id != temporaryId)
                  .toList(),
            )
          : detail;
      final conversations = cleanedDetail == null
          ? state.conversations
          : _upsertConversation(state.conversations, cleanedDetail);
      emit(
        state.copyWith(
          conversations: conversations,
          detail: cleanedDetail,
          sending: false,
          sendNotice: _messageForSendError(error),
          sendRevision: state.sendRevision + 1,
          restoreLastMessage: true,
        ),
      );
      await _cacheConversations(conversations, state.archivedCount);
    }
  }

  /// Mensaje recibido en vivo por el canal de la conversación abierta. Sólo se
  /// escucha ese canal, así que el mensaje pertenece al chat abierto: se fusiona
  /// en el hilo (por id, para no duplicar lo que ya trajo el envío o el polleo)
  /// y se actualiza el resumen en la bandeja.
  void _onRealtimeMessage(
    ChatsRealtimeMessage event,
    Emitter<ChatsState> emit,
  ) {
    final detail = state.detail;
    if (detail == null) return;

    final messages = _mergeMessages(detail.messages, [event.message]);
    final updated = detail.copyWith(
      messages: messages,
      preview: event.message.body ?? detail.preview,
      lastMessageAt: event.message.sentAt ?? detail.lastMessageAt,
    );
    final conversations = _upsertConversation(state.conversations, updated);
    emit(state.copyWith(detail: updated, conversations: conversations));
    _cacheConversations(conversations, state.archivedCount);
  }

  void _onBackToList(ChatsBackToList event, Emitter<ChatsState> emit) {
    _realtime?.unsubscribeCurrent();
    emit(
      state.copyWith(
        clearSelectedId: true,
        clearDetail: true,
        chatTaken: false,
      ),
    );
    // No esperar al próximo intervalo: la respuesta de detalle ya confirmó la
    // asignación y la lista debe conservar ese chat de inmediato.
    add(const ChatsRefreshSilent(forceList: true));
  }

  void _onDismissTaken(ChatsDismissTaken event, Emitter<ChatsState> emit) {
    _realtime?.unsubscribeCurrent();
    emit(
      state.copyWith(
        chatTaken: false,
        clearSelectedId: true,
        clearDetail: true,
      ),
    );
    add(ChatsRefreshSilent());
  }

  @override
  Future<void> close() {
    stopPolling();
    _realtimeSub?.cancel();
    return super.close();
  }

  List<ConversationSummary> _upsertConversation(
    List<ConversationSummary> current,
    ConversationSummary conversation,
  ) {
    final updated = List<ConversationSummary>.of(current);
    final index = updated.indexWhere((item) => item.id == conversation.id);

    if (index >= 0) {
      updated[index] = conversation;
    } else {
      updated.insert(0, conversation);
    }
    updated.sort(
      (a, b) => (b.lastMessageAt ?? b.createdAt).compareTo(
        a.lastMessageAt ?? a.createdAt,
      ),
    );
    return updated;
  }

  List<ConversationSummary> _parseConversations(Map<String, dynamic> data) {
    return (data['data'] as List<dynamic>? ?? const [])
        .map(
          (conversation) => ConversationSummary.fromJson(
            conversation as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  int _archivedCount(Map<String, dynamic> data) {
    return (data['meta']?['archived_count'] as num?)?.toInt() ?? 0;
  }

  String? _syncedAtFrom(Map<String, dynamic> data) {
    return data['meta']?['synced_at'] as String?;
  }

  /// Aplica una respuesta delta: inserta o reemplaza cada chat recibido y
  /// conserva el resto de la bandeja tal cual. No se pierde nada por no venir
  /// en esta tanda.
  List<ConversationSummary> _applyDelta(
    List<ConversationSummary> current,
    List<ConversationSummary> deltas,
  ) {
    if (deltas.isEmpty) return current;

    final byId = {for (final item in current) item.id: item};
    for (final delta in deltas) {
      byId[delta.id] = delta;
    }
    final merged = byId.values.toList()
      ..sort(
        (a, b) => (b.lastMessageAt ?? b.createdAt).compareTo(
          a.lastMessageAt ?? a.createdAt,
        ),
      );
    return merged;
  }

  /// Fusiona los mensajes recién traídos con los que ya estaban: reemplaza por
  /// id (para reflejar cambios de estado) y agrega los nuevos, sin descartar el
  /// historial que el polleo acotado no volvió a pedir.
  List<ChatMessage> _mergeMessages(
    List<ChatMessage> current,
    List<ChatMessage> incoming,
  ) {
    final byId = {for (final message in current) message.id: message};
    for (final message in incoming) {
      byId[message.id] = message;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final ta = DateTime.tryParse(a.createdAt) ?? DateTime(0);
        final tb = DateTime.tryParse(b.createdAt) ?? DateTime(0);
        final byTime = ta.compareTo(tb);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return merged;
  }

  /// Un chat ya asignado que el aparato confirmó nunca se elimina por una
  /// respuesta incompleta o por un backend antiguo. Los chats aún libres sí se
  /// reemplazan con la verdad del servidor, para retirarlos cuando otro gana.
  List<ConversationSummary> _mergeServerList(
    List<ConversationSummary> server,
    List<ConversationSummary> local,
  ) {
    final merged = List<ConversationSummary>.of(server);
    final ids = merged.map((item) => item.id).toSet();
    for (final conversation in local) {
      if (conversation.assignee != null && ids.add(conversation.id)) {
        merged.add(conversation);
      }
    }
    merged.sort(
      (a, b) => (b.lastMessageAt ?? b.createdAt).compareTo(
        a.lastMessageAt ?? a.createdAt,
      ),
    );
    return merged;
  }

  Future<void> _cacheConversations(
    List<ConversationSummary> conversations,
    int archivedCount,
  ) async {
    try {
      await _api.cacheConversations(
        conversations: conversations,
        archivedCount: archivedCount,
      );
    } catch (_) {
      // El caché acelera y protege la experiencia offline, pero nunca puede
      // bloquear el chat si el llavero del sistema no está disponible.
    }
  }

  String _messageForSendError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        // Sólo si trae texto: un abort() sin mensaje del lado del servidor
        // llega como {"message": ""}, y mostrarlo tal cual deja al agente
        // mirando un aviso oscuro y vacío, sin ninguna pista de qué pasó.
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }

      // 404 y 409 no llegan acá: los atiende antes la vista de "chat tomado".
      final status = error.response?.statusCode;
      if (status == 401) {
        return 'Tu sesión dejó de ser válida. Vuelve a iniciar sesión.';
      }
      if (status == 403) {
        return 'No tienes permiso para responder en este chat.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'No hay conexión con el servidor. El mensaje no fue enviado.';
      }
      if (status != null && status >= 500) {
        return 'El servidor tuvo un problema ($status). El mensaje no fue '
            'enviado.';
      }
    }
    return 'No se pudo enviar el mensaje.';
  }
}
