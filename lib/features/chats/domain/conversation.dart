class Conversation {
  const Conversation({
    required this.id,
    required this.status,
    required this.contactName,
    required this.preview,
    required this.lastMessageAt,
  });
  final int id;
  final String status;
  final String contactName;
  final String? preview;
  final DateTime? lastMessageAt;
  bool get isClosed => status == 'closed';

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as int,
    status: json['status'] as String,
    contactName: (json['contact'] as Map)['name'] as String,
    preview: json['preview'] as String?,
    lastMessageAt: DateTime.tryParse(json['last_message_at']?.toString() ?? ''),
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.direction,
    required this.status,
    required this.sentAt,
  });
  final int id;
  final String body;
  final String direction;
  final String? status;
  final DateTime sentAt;
  bool get outbound => direction == 'outbound';
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    body: json['body']?.toString() ?? '',
    direction: json['direction'] as String,
    status: json['status'] as String?,
    sentAt: DateTime.parse((json['sent_at'] ?? json['created_at']).toString()),
  );
}
