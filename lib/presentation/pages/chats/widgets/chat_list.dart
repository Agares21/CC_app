import 'package:flutter/material.dart';
import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/core/theme/app_text_styles.dart';
import 'package:cloud_api_cc/data/models/conversation_model.dart';

/// Widget de lista de chats.
///
/// Muestra la barra de búsqueda, toggle activo/archivado,
/// y los items de conversación con avatar, nombre, preview y unread badge.
class ChatList extends StatefulWidget {
  final List<ConversationSummary> conversations;
  final bool loading;
  final int archivedCount;
  final ValueChanged<int> onSelectConversation;

  const ChatList({
    super.key,
    required this.conversations,
    required this.loading,
    required this.archivedCount,
    required this.onSelectConversation,
  });

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? widget.conversations
        : widget.conversations.where((c) {
            final name = c.contact.name.toLowerCase();
            final preview = c.preview?.toLowerCase() ?? '';
            return name.contains(_searchQuery) || preview.contains(_searchQuery);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Chats', style: AppTextStyles.headingMd),
                      if (widget.archivedCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.inputBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${widget.archivedCount} archivados',
                            style: AppTextStyles.captionXs,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Buscador
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.mutedForeground),
                      hintText: 'Buscar conversación...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Lista
            Expanded(
              child: widget.loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48,
                                  color: AppColors.mutedForeground.withValues(alpha: 0.4)),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No se encontraron conversaciones.'
                                    : 'No hay conversaciones activas.',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: filtered.length,
                          separatorBuilder: (context, i) => const Divider(indent: 72),
                          itemBuilder: (context, index) {
                            final conv = filtered[index];
                            return _ChatItem(
                              conversation: conv,
                              onTap: () => widget.onSelectConversation(conv.id),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item individual de conversación en la lista.
class _ChatItem extends StatelessWidget {
  final ConversationSummary conversation;
  final VoidCallback onTap;

  const _ChatItem({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final contact = conversation.contact;
    final initial = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.brand.withValues(alpha: 0.1),
              child: Text(
                initial,
                style: AppTextStyles.headingSm.copyWith(color: AppColors.brand),
              ),
            ),
            const SizedBox(width: 12),

            // Nombre + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.name,
                          style: AppTextStyles.bodySm.copyWith(
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.assignee != null)
                        Text(
                          conversation.assignee!.name,
                          style: AppTextStyles.captionXs,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (conversation.preview != null)
                    Text(
                      conversation.preview!,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Unread badge
            if (conversation.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: AppColors.brandAccentForeground,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
