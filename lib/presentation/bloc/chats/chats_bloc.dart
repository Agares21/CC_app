import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_api_cc/data/api/conversations_api.dart';
import 'package:cloud_api_cc/data/models/conversation_model.dart';

abstract class ChatsEvent extends Equatable {
  const ChatsEvent();
  @override
  List<Object?> get props => [];
}

class ChatsLoadRequested extends ChatsEvent {}

class ChatsRefreshSilent extends ChatsEvent {}

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
    bool clearSelectedId = false,
    bool clearDetail = false,
    bool clearError = false,
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
  ];
}

/// Gestiona la bandeja de chats y el hilo activo.
class ChatsBloc extends Bloc<ChatsEvent, ChatsState> {
  final ConversationsApi _api;
  Timer? _pollTimer;
  static const _pollDuration = Duration(seconds: 4);

  ChatsBloc({required ConversationsApi api})
    : _api = api,
      super(const ChatsState()) {
    on<ChatsLoadRequested>(_onLoad);
    on<ChatsRefreshSilent>(_onRefreshSilent);
    on<ChatsSelectConversation>(_onSelect);
    on<ChatsSendMessage>(_onSendMessage);
    on<ChatsBackToList>(_onBackToList);
    on<ChatsDismissTaken>(_onDismissTaken);
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
    emit(state.copyWith(loadingList: true, clearError: true));
    try {
      final data = await _api.getConversations();
      final list = (data['data'] as List<dynamic>)
          .map((c) => ConversationSummary.fromJson(c as Map<String, dynamic>))
          .toList();
      emit(
        state.copyWith(
          conversations: list,
          archivedCount: (data['meta']?['archived_count'] as int?) ?? 0,
          loadingList: false,
        ),
      );
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
    try {
      final data = await _api.getConversations();
      final list = (data['data'] as List<dynamic>)
          .map((c) => ConversationSummary.fromJson(c as Map<String, dynamic>))
          .toList();
      emit(
        state.copyWith(
          conversations: list,
          archivedCount: (data['meta']?['archived_count'] as int?) ?? 0,
        ),
      );
      if (state.selectedId != null) {
        final d = await _api.getConversation(state.selectedId!);
        final detail = ConversationDetail.fromJson(
          d['data'] as Map<String, dynamic>,
        );
        emit(
          state.copyWith(
            conversations: _upsertConversation(state.conversations, detail),
            detail: detail,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _onSelect(
    ChatsSelectConversation event,
    Emitter<ChatsState> emit,
  ) async {
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
    if (state.selectedId == null) return;
    emit(state.copyWith(sending: true));
    try {
      await _api.sendMessage(
        conversationId: state.selectedId!,
        body: event.body,
        mediaPath: event.mediaPath,
        mediaName: event.mediaName,
      );
      final data = await _api.getConversation(state.selectedId!);
      final detail = ConversationDetail.fromJson(
        data['data'] as Map<String, dynamic>,
      );
      emit(
        state.copyWith(
          conversations: _upsertConversation(state.conversations, detail),
          detail: detail,
          sending: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(sending: false, error: 'No se pudo enviar el mensaje.'),
      );
    }
  }

  void _onBackToList(ChatsBackToList event, Emitter<ChatsState> emit) {
    emit(
      state.copyWith(
        clearSelectedId: true,
        clearDetail: true,
        chatTaken: false,
      ),
    );
    // No esperar al próximo intervalo: la respuesta de detalle ya confirmó la
    // asignación y la lista debe conservar ese chat de inmediato.
    add(ChatsRefreshSilent());
  }

  void _onDismissTaken(ChatsDismissTaken event, Emitter<ChatsState> emit) {
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

    return updated;
  }
}
