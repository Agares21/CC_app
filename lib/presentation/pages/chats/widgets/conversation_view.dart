import 'package:flutter/material.dart';
import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/core/theme/app_text_styles.dart';
import 'package:cloud_api_cc/data/models/conversation_model.dart';

/// Vista de conversación activa con burbujas de mensajes y barra de input.
class ConversationView extends StatefulWidget {
  final ConversationDetail? detail;
  final bool loading;
  final bool sending;
  final VoidCallback onBack;
  final VoidCallback onShowProfile;
  final ValueChanged<String> onSendMessage;

  const ConversationView({
    super.key,
    required this.detail,
    required this.loading,
    required this.sending,
    required this.onBack,
    required this.onShowProfile,
    required this.onSendMessage,
  });

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll al final cuando hay nuevos mensajes.
    if (widget.detail != null &&
        oldWidget.detail != null &&
        widget.detail!.messages.length > oldWidget.detail!.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _send() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header de la conversación
        _buildHeader(),
        const Divider(height: 1),

        // Mensajes
        Expanded(
          child: widget.loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
              : widget.detail == null
                  ? Center(
                      child: Text('Error al cargar la conversación.',
                          style: AppTextStyles.caption),
                    )
                  : Container(
                      color: AppColors.chatBackground,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: widget.detail!.messages.length,
                        itemBuilder: (context, index) {
                          final message = widget.detail!.messages[index];
                          return _MessageBubble(message: message);
                        },
                      ),
                    ),
        ),

        // Barra de input
        if (widget.detail?.canSend == true) _buildInputBar(),
      ],
    );
  }

  Widget _buildHeader() {
    final contact = widget.detail?.contact;
    final initial = contact?.name.isNotEmpty == true ? contact!.name[0].toUpperCase() : '?';

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: widget.onBack,
            color: AppColors.brand,
          ),
          GestureDetector(
            onTap: widget.onShowProfile,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                  child: Text(
                    initial,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact?.name ?? 'Contacto',
                      style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w500),
                    ),
                    if (contact?.phone != null)
                      Text(contact!.phone!, style: AppTextStyles.captionXs),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.person_outline, size: 20),
            onPressed: widget.onShowProfile,
            color: AppColors.brand,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          // Adjuntar
          IconButton(
            icon: const Icon(Icons.attach_file, size: 20),
            onPressed: () {},
            color: AppColors.mutedForeground,
          ),

          // Campo de texto
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Botón enviar (amarillo como en la web)
          Material(
            color: AppColors.brandAccent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.sending ? null : _send,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: widget.sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandAccentForeground,
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        size: 18,
                        color: AppColors.brandAccentForeground,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Burbuja de mensaje individual.
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isOut = message.isOutbound;

    return Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isOut ? AppColors.brand : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isOut ? 14 : 4),
            bottomRight: Radius.circular(isOut ? 4 : 14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Texto del mensaje
            if (message.body != null && message.body!.isNotEmpty)
              Text(
                message.body!,
                style: AppTextStyles.bodySm.copyWith(
                  color: isOut ? Colors.white : AppColors.foreground,
                ),
              ),

            const SizedBox(height: 4),

            // Estado + hora
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: AppTextStyles.captionXs.copyWith(
                    color: isOut ? Colors.white70 : AppColors.mutedForeground,
                    fontSize: 10,
                  ),
                ),
                if (isOut) ...[
                  const SizedBox(width: 4),
                  _statusIcon(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(String? status) {
    switch (status) {
      case 'sent':
        return const Icon(Icons.check, size: 12, color: Colors.white70);
      case 'delivered':
        return const Icon(Icons.done_all, size: 12, color: Colors.white70);
      case 'read':
        return const Icon(Icons.done_all, size: 12, color: Color(0xFF53BDEB));
      case 'failed':
        return const Icon(Icons.error_outline, size: 12, color: Colors.redAccent);
      default:
        return const Icon(Icons.access_time, size: 12, color: Colors.white54);
    }
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
