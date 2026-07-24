import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/core/theme/app_text_styles.dart';
import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/models/conversation_model.dart';
import 'package:cloud_api_cc/presentation/pages/chats/widgets/message_attachments.dart';

/// Envío de un mensaje: texto y, opcionalmente, un adjunto ya elegido.
typedef SendMessageCallback =
    void Function(String body, {String? mediaPath, String? mediaName});

/// Los mismos emojis que ofrece el panel web, para que ambos clientes se
/// sientan iguales. El teclado del sistema sigue estando para el resto.
const _emojis = [
  '😀', '😃', '😄', '😁', '😊', '🙂', '😉', '😍',
  '😘', '😎', '🥳', '😅', '😂', '🤣', '😢', '😮',
  '👍', '👏', '🙌', '🙏', '💪', '👌', '✅', '❌',
  '⭐', '🔥', '❤️', '💛', '💙', '🎉', '📌', '⏰',
];

/// Archivo elegido en el compositor, todavía sin enviar.
class _PendingAttachment {
  final String path;
  final String name;

  const _PendingAttachment({required this.path, required this.name});

  /// WhatsApp no admite texto junto a un audio (lo valida el backend).
  bool get isAudio {
    final lower = name.toLowerCase();

    return const [
      '.mp3',
      '.m4a',
      '.aac',
      '.ogg',
      '.opus',
      '.wav',
      '.amr',
    ].any(lower.endsWith);
  }

  String get readableSize {
    final bytes = File(path).existsSync() ? File(path).lengthSync() : 0;
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Vista de conversación activa con burbujas de mensajes y barra de input.
class ConversationView extends StatefulWidget {
  final ConversationDetail? detail;
  final bool loading;
  final bool sending;
  final String? sendNotice;
  final int sendRevision;
  final bool restoreLastMessage;
  final VoidCallback onBack;
  final VoidCallback onShowProfile;
  final SendMessageCallback onSendMessage;

  const ConversationView({
    super.key,
    required this.detail,
    required this.loading,
    required this.sending,
    required this.sendNotice,
    required this.sendRevision,
    required this.restoreLastMessage,
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
  final _audio = ChatAudioController();
  final _recorder = AudioRecorder();
  String? _lastSubmittedText;
  _PendingAttachment? _attachment;
  bool _emojiOpen = false;
  bool _recording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  /// Los adjuntos se sirven con Bearer. Se resuelven una vez por hilo en vez de
  /// leer el llavero en cada burbuja.
  Map<String, String>? _mediaHeaders;

  @override
  void initState() {
    super.initState();

    context.read<ApiClient>().mediaHeaders().then((headers) {
      if (mounted) setState(() => _mediaHeaders = headers);
    });

    // El botón de la derecha alterna entre micrófono y enviar según si hay algo
    // para mandar, así que hay que repintar cuando cambia el texto.
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.sendRevision != oldWidget.sendRevision) {
      final submittedText = _lastSubmittedText;
      if (widget.restoreLastMessage &&
          submittedText != null &&
          _messageController.text.isEmpty) {
        _messageController.value = TextEditingValue(
          text: submittedText,
          selection: TextSelection.collapsed(offset: submittedText.length),
        );
      }
      _lastSubmittedText = null;

      final notice = widget.sendNotice;
      if (notice != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notice)));
        });
      }
    }

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
    if (widget.sending) return;

    final text = _messageController.text.trim();
    final attachment = _attachment;
    if (text.isEmpty && attachment == null) return;

    // Con audio el backend rechaza el caption, así que se manda solo el archivo
    // y el texto tipeado se conserva para enviarlo aparte.
    final onlyAudio = attachment?.isAudio ?? false;

    _lastSubmittedText = text;
    widget.onSendMessage(
      onlyAudio ? '' : text,
      mediaPath: attachment?.path,
      mediaName: attachment?.name,
    );

    if (!onlyAudio) _messageController.clear();
    setState(() => _attachment = null);
  }

  Future<void> _pickFromGallery() async {
    // pickMedia deja elegir foto o video con el mismo selector.
    final file = await ImagePicker().pickMedia();
    _useFile(file?.path, file?.name);
  }

  Future<void> _pickFromCamera() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    _useFile(file?.path, file?.name);
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles();
    final file = result?.files.singleOrNull;
    _useFile(file?.path, file?.name);
  }

  void _useFile(String? path, String? name) {
    if (path == null) return;

    setState(() {
      _attachment = _PendingAttachment(
        path: path,
        name: name ?? path.split('/').last,
      );
    });
  }

  /// Inserta el emoji donde está el cursor, sin pisar lo ya escrito.
  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    _messageController.value = TextEditingValue(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _startRecording() async {
    // hasPermission pide el permiso al sistema si todavía no se otorgó.
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Necesitamos permiso del micrófono para grabar.'),
          ),
        );
      return;
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/nota-${DateTime.now().millisecondsSinceEpoch}.m4a';

    // AAC en contenedor .m4a (audio/mp4): uno de los formatos que acepta la
    // Cloud API de WhatsApp.
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    if (!mounted) return;
    setState(() {
      _recording = true;
      _recordSeconds = 0;
      _emojiOpen = false;
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  /// [keep] false descarta la grabación y borra el archivo.
  Future<void> _stopRecording({required bool keep}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();

    if (mounted) setState(() => _recording = false);
    if (path == null) return;

    if (!keep) {
      unawaited(File(path).delete().catchError((_) => File(path)));
      return;
    }

    _useFile(path, 'nota-de-voz.m4a');
  }

  void _openAttachMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              subtitle: const Text('Fotos y videos'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Documento'),
              subtitle: const Text('PDF, Word, Excel, audio…'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
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
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : widget.detail == null
              ? Center(
                  child: Text(
                    'Error al cargar la conversación.',
                    style: AppTextStyles.caption,
                  ),
                )
              : Container(
                  color: AppColors.chatBackground,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: widget.detail!.messages.length,
                    itemBuilder: (context, index) {
                      final message = widget.detail!.messages[index];
                      return _MessageBubble(
                        message: message,
                        mediaHeaders: _mediaHeaders,
                        audioController: _audio,
                      );
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
    final initial = contact?.name.isNotEmpty == true
        ? contact!.name[0].toUpperCase()
        : '?';

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
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_emojiOpen && !_recording) _buildEmojiPanel(),
          if (_attachment != null) _buildAttachmentChip(),
          if (_recording) _buildRecordingBar() else _buildComposerRow(),
        ],
      ),
    );
  }

  Widget _buildComposerRow() {
    final audioAttached = _attachment?.isAudio ?? false;
    // Mostramos micrófono mientras no haya nada que mandar, como WhatsApp.
    final hasContent =
        _messageController.text.trim().isNotEmpty || _attachment != null;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.attach_file, size: 20),
          onPressed: _openAttachMenu,
          tooltip: 'Adjuntar',
          color: AppColors.mutedForeground,
        ),
        IconButton(
          icon: Icon(
            _emojiOpen ? Icons.keyboard : Icons.emoji_emotions_outlined,
            size: 20,
          ),
          onPressed: audioAttached
              ? null
              : () => setState(() => _emojiOpen = !_emojiOpen),
          tooltip: 'Emojis',
          color: _emojiOpen ? AppColors.brand : AppColors.mutedForeground,
        ),

        // Campo de texto
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 100),
            child: TextField(
              controller: _messageController,
              maxLines: null,
              enabled: !audioAttached,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              onTap: () {
                if (_emojiOpen) setState(() => _emojiOpen = false);
              },
              decoration: InputDecoration(
                hintText: audioAttached
                    ? 'El audio se envía sin texto'
                    : 'Escribe un mensaje...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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

        // Micrófono o enviar, según haya algo para mandar.
        Material(
          color: AppColors.brandAccent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.sending
                ? null
                : hasContent
                ? _send
                : _startRecording,
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
                  : Icon(
                      hasContent ? Icons.send : Icons.mic,
                      size: 18,
                      color: AppColors.brandAccentForeground,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// Barra que reemplaza al compositor mientras se graba una nota de voz.
  Widget _buildRecordingBar() {
    final minutes = (_recordSeconds ~/ 60).toString();
    final seconds = (_recordSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text('Grabando… $minutes:$seconds', style: AppTextStyles.bodySm),
        const Spacer(),
        TextButton(
          onPressed: () => _stopRecording(keep: false),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 4),
        Material(
          color: AppColors.brandAccent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _stopRecording(keep: true),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(
                Icons.stop,
                size: 18,
                color: AppColors.brandAccentForeground,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiPanel() {
    return Container(
      height: 176,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.count(
        crossAxisCount: 8,
        padding: const EdgeInsets.all(8),
        children: [
          for (final emoji in _emojis)
            InkWell(
              onTap: () => _insertEmoji(emoji),
              borderRadius: BorderRadius.circular(8),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
        ],
      ),
    );
  }

  /// Vista previa del archivo elegido, con opción de quitarlo antes de enviar.
  Widget _buildAttachmentChip() {
    final attachment = _attachment!;
    final size = attachment.readableSize;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  size.isEmpty
                      ? attachment.name
                      : '${attachment.name} · $size',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionXs,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _attachment = null),
                child: Text(
                  'Quitar',
                  style: AppTextStyles.captionXs.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (attachment.isAudio)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'WhatsApp no permite texto junto a un audio: se envía solo el audio.',
                style: AppTextStyles.captionXs.copyWith(
                  color: AppColors.mutedForeground,
                  fontSize: 10,
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
  final Map<String, String>? mediaHeaders;
  final ChatAudioController audioController;

  const _MessageBubble({
    required this.message,
    required this.mediaHeaders,
    required this.audioController,
  });

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
            // Adjuntos (imagen, video, audio o documento).
            if (message.media.isNotEmpty)
              MessageAttachments(
                message: message,
                headers: mediaHeaders,
                audioController: audioController,
                isOutbound: isOut,
              ),

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
        return const Icon(
          Icons.error_outline,
          size: 12,
          color: Colors.redAccent,
        );
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
