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
    AssigneeModel? assignee,
    bool? canSend,
  }) {
    return ConversationSummary(
      id: id,
      status: status,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      contact: contact,
      assignee: assignee ?? this.assignee,
      preview: preview ?? this.preview,
      canSend: canSend ?? this.canSend,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'created_at': createdAt,
    'last_message_at': lastMessageAt,
    'unread_count': unreadCount,
    'contact': contact.toJson(),
    'assignee': assignee?.toJson(),
    'preview': preview,
    'can_send': canSend,
  };

  @override
  List<Object?> get props => [
    id,
    status,
    createdAt,
    lastMessageAt,
    unreadCount,
    contact.id,
    contact.name,
    assignee?.id,
    preview,
    canSend,
  ];
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

  // Sin esto, dos detalles con el mismo resumen pero distintos mensajes serían
  // "iguales" para Equatable (los mensajes no están en los props del resumen),
  // y el bloc no re-emitiría cuando cambia el estado de un mensaje o llega uno
  // nuevo: la burbuja no se actualizaría.
  @override
  List<Object?> get props => [...super.props, messages];

  @override
  ConversationDetail copyWith({
    List<ChatMessage>? messages,
    String? lastMessageAt,
    String? preview,
    int? unreadCount,
    AssigneeModel? assignee,
    bool? canSend,
  }) {
    return ConversationDetail(
      id: id,
      status: status,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      contact: contact,
      assignee: assignee ?? this.assignee,
      preview: preview ?? this.preview,
      canSend: canSend ?? this.canSend,
      messages: messages ?? this.messages,
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
  bool get isAudio => mimeType?.startsWith('audio/') ?? false;

  /// Todo lo que no es imagen, video ni audio se trata como documento: es el
  /// mismo criterio que usa el backend para hablarle a la Cloud API.
  bool get isDocument => !isImage && !isVideo && !isAudio;

  /// Nombre a mostrar cuando el adjunto no trae uno propio.
  String get displayName => originalFilename?.trim().isNotEmpty == true
      ? originalFilename!
      : 'Archivo adjunto';

  /// Peso legible ("340 KB", "1.2 MB"). Vacío si el backend no lo informó.
  String get readableSize {
    final bytes = size;
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Etiqueta corta del tipo, para la tarjeta de documento.
  String get kindLabel {
    final mime = mimeType ?? '';
    if (mime == 'application/pdf') return 'PDF';
    if (mime.contains('word')) return 'Word';
    if (mime.contains('sheet') || mime.contains('excel')) return 'Excel';
    if (mime.contains('presentation') || mime.contains('powerpoint')) {
      return 'PowerPoint';
    }
    if (mime.contains('zip') || mime.contains('compressed')) return 'ZIP';
    if (mime.startsWith('text/')) return 'Texto';

    return 'Archivo';
  }

  factory MediaAttachment.fromJson(Map<String, dynamic> json) =>
      MediaAttachment(
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'wa_id': waId,
    'name': name,
    'phone': phone,
  };
}

class AssigneeModel {
  final int id;
  final String name;

  const AssigneeModel({required this.id, required this.name});

  factory AssigneeModel.fromJson(Map<String, dynamic> json) =>
      AssigneeModel(id: json['id'] as int, name: json['name'] as String? ?? '');

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class MessageSender {
  final int id;
  final String name;

  const MessageSender({required this.id, required this.name});

  factory MessageSender.fromJson(Map<String, dynamic> json) =>
      MessageSender(id: json['id'] as int, name: json['name'] as String? ?? '');
}
