import 'package:equatable/equatable.dart';

/// Resumen de una conversación en la bandeja.
class ConversationSummary extends Equatable {
  final int id;
  final String status;
  final String createdAt;
  final String? lastMessageAt;
  final int unreadCount;
  final ContactModel contact;
  final AssigneeModel? assignee;
  final String? preview;
  final bool canSend;

  const ConversationSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    this.lastMessageAt,
    required this.unreadCount,
    required this.contact,
    this.assignee,
    this.preview,
    required this.canSend,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id'] as int,
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      lastMessageAt: json['last_message_at'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      contact: ContactModel.fromJson(json['contact'] as Map<String, dynamic>),
      assignee: json['assignee'] != null
          ? AssigneeModel.fromJson(json['assignee'] as Map<String, dynamic>)
          : null,
      preview: json['preview'] as String?,
      canSend: json['can_send'] as bool? ?? true,
    );
  }

  ConversationSummary copyWith({
    int? unreadCount,
    String? preview,
    String? lastMessageAt,
  }) {
    return ConversationSummary(
      id: id,
      status: status,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      contact: contact,
      assignee: assignee,
      preview: preview ?? this.preview,
      canSend: canSend,
    );
  }

  @override
  List<Object?> get props => [id, status, unreadCount, lastMessageAt];
}

/// Detalle completo de una conversación.
class ConversationDetail extends ConversationSummary {
  final List<ChatMessage> messages;

  const ConversationDetail({
    required super.id,
    required super.status,
    required super.createdAt,
    super.lastMessageAt,
    required super.unreadCount,
    required super.contact,
    super.assignee,
    super.preview,
    required super.canSend,
    required this.messages,
  });

  factory ConversationDetail.fromJson(Map<String, dynamic> json) {
    final msgs = (json['messages'] as List<dynamic>? ?? [])
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    return ConversationDetail(
      id: json['id'] as int,
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      lastMessageAt: json['last_message_at'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      contact: ContactModel.fromJson(json['contact'] as Map<String, dynamic>),
      assignee: json['assignee'] != null
          ? AssigneeModel.fromJson(json['assignee'] as Map<String, dynamic>)
          : null,
      preview: json['preview'] as String?,
      canSend: json['can_send'] as bool? ?? true,
      messages: msgs,
    );
  }
}

/// Mensaje individual.
class ChatMessage extends Equatable {
  final int id;
  final String direction;
  final String type;
  final String? body;
  final String? status;
  final String? sentAt;
  final String createdAt;
  final List<MediaAttachment> media;
  final MessageSender? sender;

  const ChatMessage({
    required this.id,
    required this.direction,
    required this.type,
    this.body,
    this.status,
    this.sentAt,
    required this.createdAt,
    required this.media,
    this.sender,
  });

  bool get isOutbound => direction == 'outbound';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final mediaList = (json['media'] as List<dynamic>? ?? [])
        .map((m) => MediaAttachment.fromJson(m as Map<String, dynamic>))
        .toList();
    return ChatMessage(
      id: json['id'] as int,
      direction: json['direction'] as String? ?? 'inbound',
      type: json['type'] as String? ?? 'text',
      body: json['body'] as String?,
      status: json['status'] as String?,
      sentAt: json['sent_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      media: mediaList,
      sender: json['sender'] != null
          ? MessageSender.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, direction, body, status];
}

class MediaAttachment {
  final int id;
  final String url;
  final String? mimeType;
  final String? originalFilename;
  final int? size;

  const MediaAttachment({
    required this.id,
    required this.url,
    this.mimeType,
    this.originalFilename,
    this.size,
  });

  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isVideo => mimeType?.startsWith('video/') ?? false;

  factory MediaAttachment.fromJson(Map<String, dynamic> json) => MediaAttachment(
        id: json['id'] as int,
        url: json['url'] as String? ?? '',
        mimeType: json['mime_type'] as String?,
        originalFilename: json['original_filename'] as String?,
        size: json['size'] as int?,
      );
}

class ContactModel {
  final int id;
  final String waId;
  final String name;
  final String? phone;

  const ContactModel({
    required this.id,
    required this.waId,
    required this.name,
    this.phone,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) => ContactModel(
        id: json['id'] as int,
        waId: json['wa_id'] as String? ?? '',
        name: json['name'] as String? ?? 'Sin nombre',
        phone: json['phone'] as String?,
      );
}

class AssigneeModel {
  final int id;
  final String name;

  const AssigneeModel({required this.id, required this.name});

  factory AssigneeModel.fromJson(Map<String, dynamic> json) => AssigneeModel(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
      );
}

class MessageSender {
  final int id;
  final String name;

  const MessageSender({required this.id, required this.name});

  factory MessageSender.fromJson(Map<String, dynamic> json) => MessageSender(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
      );
}
