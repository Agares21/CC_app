import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/chat_repository.dart';
import '../domain/conversation.dart';

final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(ref.watch(dioProvider)),
);

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});
  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  List<Conversation>? conversations;
  Conversation? selected;
  List<ChatMessage> messages = [];
  final search = TextEditingController();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshMessages(),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await ref.read(chatRepositoryProvider).all();
    if (!mounted) return;
    setState(() {
      conversations = data;
      selected ??= data.isEmpty ? null : data.first;
    });
    await _refreshMessages();
  }

  Future<void> _refreshMessages() async {
    final chat = selected;
    if (chat == null) return;
    final data = await ref.read(chatRepositoryProvider).messages(chat.id);
    if (mounted) setState(() => messages = data);
  }

  @override
  Widget build(BuildContext context) {
    if (conversations == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final wide = MediaQuery.sizeOf(context).width >= 760;
    if (!wide && selected != null) {
      return _ConversationView(
        conversation: selected!,
        messages: messages,
        onBack: () => setState(() => selected = null),
        onSent: _refreshMessages,
      );
    }
    final list = _ConversationList(
      items: conversations!,
      search: search,
      selected: selected,
      onSelected: (chat) async {
        setState(() => selected = chat);
        await _refreshMessages();
      },
    );
    return wide
        ? Row(
            children: [
              SizedBox(width: 320, child: list),
              const SizedBox(width: 12),
              Expanded(
                child: selected == null
                    ? const Center(child: Text('Selecciona un chat'))
                    : _ConversationView(
                        conversation: selected!,
                        messages: messages,
                        onSent: _refreshMessages,
                      ),
              ),
            ],
          )
        : list;
  }
}

class _ConversationList extends StatefulWidget {
  const _ConversationList({
    required this.items,
    required this.search,
    required this.selected,
    required this.onSelected,
  });
  final List<Conversation> items;
  final TextEditingController search;
  final Conversation? selected;
  final ValueChanged<Conversation> onSelected;
  @override
  State<_ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<_ConversationList> {
  @override
  Widget build(BuildContext context) {
    final q = widget.search.text.toLowerCase();
    final items = widget.items
        .where((c) => c.contactName.toLowerCase().contains(q))
        .toList();
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chats',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: widget.search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar contacto',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, index) {
                final chat = items[index];
                return ListTile(
                  selected: widget.selected?.id == chat.id,
                  selectedTileColor: AppTheme.primary.withValues(alpha: .08),
                  leading: CircleAvatar(
                    child: Text(
                      chat.contactName.characters.first.toUpperCase(),
                    ),
                  ),
                  title: Text(chat.contactName),
                  subtitle: Text(
                    chat.preview ?? 'Sin mensajes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    Icons.circle,
                    size: 9,
                    color: chat.isClosed ? Colors.grey : AppTheme.accent,
                  ),
                  onTap: () => widget.onSelected(chat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationView extends ConsumerStatefulWidget {
  const _ConversationView({
    required this.conversation,
    required this.messages,
    required this.onSent,
    this.onBack,
  });
  final Conversation conversation;
  final List<ChatMessage> messages;
  final Future<void> Function() onSent;
  final VoidCallback? onBack;
  @override
  ConsumerState<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends ConsumerState<_ConversationView> {
  final input = TextEditingController();
  bool sending = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (input.text.trim().isEmpty) return;
    setState(() => sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .send(widget.conversation.id, input.text.trim());
      input.clear();
      await widget.onSent();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        ListTile(
          leading: widget.onBack == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
          title: Text(
            widget.conversation.contactName,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            widget.conversation.isClosed
                ? 'Conversación cerrada'
                : 'Conversación abierta',
          ),
        ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: widget.messages.length,
            itemBuilder: (_, i) {
              final message = widget.messages[widget.messages.length - 1 - i];
              return Align(
                alignment: message.outbound
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  constraints: const BoxConstraints(maxWidth: 460),
                  decoration: BoxDecoration(
                    color: message.outbound ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.body,
                        style: TextStyle(
                          color: message.outbound
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      Text(
                        DateFormat.Hm().format(message.sentAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: message.outbound
                              ? Colors.white70
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.conversation.isClosed)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('La ventana de atención de 24 horas finalizó.'),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    onSubmitted: (_) => send(),
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.primary,
                  ),
                  onPressed: sending ? null : send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
