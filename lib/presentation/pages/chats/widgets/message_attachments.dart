import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/core/theme/app_text_styles.dart';
import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/models/conversation_model.dart';

/// Reproductor de audio compartido por todo el hilo.
///
/// Uno solo para todas las burbujas: si cada nota de voz tuviera el suyo,
/// podrían sonar varias a la vez y cada una retendría un decodificador.
class ChatAudioController {
  final AudioPlayer player = AudioPlayer();
  int? _currentId;

  int? get currentId => _currentId;

  /// Reproduce o pausa el audio pedido. Si ya sonaba otro, lo reemplaza.
  Future<void> toggle(
    MediaAttachment media,
    String url,
    Map<String, String> headers,
  ) async {
    if (_currentId == media.id) {
      player.playing ? await player.pause() : await player.play();
      return;
    }

    _currentId = media.id;
    await player.setAudioSource(
      AudioSource.uri(Uri.parse(url), headers: headers),
    );
    await player.play();
  }

  void dispose() => player.dispose();
}

/// Adjuntos de un mensaje. Cada tipo se muestra como corresponde: la imagen
/// inline, el video y el documento como tarjeta, y el audio con su reproductor.
class MessageAttachments extends StatelessWidget {
  final ChatMessage message;
  final Map<String, String>? headers;
  final ChatAudioController audioController;
  final bool isOutbound;

  const MessageAttachments({
    super.key,
    required this.message,
    required this.headers,
    required this.audioController,
    required this.isOutbound,
  });

  @override
  Widget build(BuildContext context) {
    if (message.media.isEmpty) return const SizedBox.shrink();

    final resolvedHeaders = headers;
    if (resolvedHeaders == null) {
      // Todavía se está leyendo el token del llavero.
      return const SizedBox(
        height: 60,
        width: 160,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final client = context.read<ApiClient>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: message.media.map((media) {
        final url = client.absoluteUrl(media.url);

        Widget child;
        if (media.isImage) {
          child = _ImageAttachment(media: media, url: url, headers: resolvedHeaders);
        } else if (media.isVideo) {
          child = _VideoAttachment(
            media: media,
            url: url,
            headers: resolvedHeaders,
            isOutbound: isOutbound,
          );
        } else if (media.isAudio) {
          child = _AudioAttachment(
            media: media,
            url: url,
            headers: resolvedHeaders,
            controller: audioController,
            isOutbound: isOutbound,
          );
        } else {
          child = _DocumentAttachment(
            media: media,
            url: url,
            isOutbound: isOutbound,
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: child,
        );
      }).toList(),
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  final MediaAttachment media;
  final String url;
  final Map<String, String> headers;

  const _ImageAttachment({
    required this.media,
    required this.url,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullscreenImagePage(
            url: url,
            headers: headers,
            title: media.displayName,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          httpHeaders: headers,
          fit: BoxFit.cover,
          width: 220,
          placeholder: (_, _) => const SizedBox(
            width: 220,
            height: 150,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, _, _) => const SizedBox(
            width: 220,
            height: 150,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }
}

class _FullscreenImagePage extends StatelessWidget {
  final String url;
  final Map<String, String> headers;
  final String title;

  const _FullscreenImagePage({
    required this.url,
    required this.headers,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: CachedNetworkImage(imageUrl: url, httpHeaders: headers),
        ),
      ),
    );
  }
}

/// El video no se reproduce dentro de la lista: cada controlador retiene un
/// decodificador y en un hilo largo eso se vuelve pesado. Se muestra una
/// tarjeta y se abre a pantalla completa al tocarla.
class _VideoAttachment extends StatelessWidget {
  final MediaAttachment media;
  final String url;
  final Map<String, String> headers;
  final bool isOutbound;

  const _VideoAttachment({
    required this.media,
    required this.url,
    required this.headers,
    required this.isOutbound,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullscreenVideoPage(
            url: url,
            headers: headers,
            title: media.displayName,
          ),
        ),
      ),
      child: Container(
        width: 220,
        height: 124,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.play_circle_fill, size: 46, color: Colors.white),
            Positioned(
              left: 8,
              right: 8,
              bottom: 6,
              child: Text(
                [
                  'Video',
                  if (media.readableSize.isNotEmpty) media.readableSize,
                ].join(' · '),
                style: AppTextStyles.captionXs.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenVideoPage extends StatefulWidget {
  final String url;
  final Map<String, String> headers;
  final String title;

  const _FullscreenVideoPage({
    required this.url,
    required this.headers,
    required this.title,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: widget.headers,
    );
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          _controller.play();
        })
        .catchError((Object e) {
          if (!mounted) return;
          setState(() => _error = 'No se pudo reproducir el video.');
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.white70))
            : !_ready
            ? const CircularProgressIndicator()
            : AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                  ],
                ),
              ),
      ),
      floatingActionButton: _ready
          ? FloatingActionButton(
              backgroundColor: AppColors.brand,
              onPressed: () => setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              }),
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}

class _AudioAttachment extends StatelessWidget {
  final MediaAttachment media;
  final String url;
  final Map<String, String> headers;
  final ChatAudioController controller;
  final bool isOutbound;

  const _AudioAttachment({
    required this.media,
    required this.url,
    required this.headers,
    required this.controller,
    required this.isOutbound,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isOutbound ? Colors.white : AppColors.foreground;
    final muted = isOutbound ? Colors.white70 : AppColors.mutedForeground;

    return StreamBuilder<PlayerState>(
      stream: controller.player.playerStateStream,
      builder: (context, snapshot) {
        final isCurrent = controller.currentId == media.id;
        final playing = isCurrent && (snapshot.data?.playing ?? false);

        return Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isOutbound
                ? Colors.white.withValues(alpha: 0.15)
                : AppColors.inputBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => controller.toggle(media, url, headers),
                borderRadius: BorderRadius.circular(18),
                child: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  size: 34,
                  color: isOutbound ? Colors.white : AppColors.brand,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nota de voz',
                      style: AppTextStyles.captionXs.copyWith(color: foreground),
                    ),
                    const SizedBox(height: 2),
                    StreamBuilder<Duration>(
                      stream: controller.player.positionStream,
                      builder: (context, positionSnapshot) {
                        final total = controller.player.duration;
                        final position = isCurrent
                            ? (positionSnapshot.data ?? Duration.zero)
                            : Duration.zero;

                        return Text(
                          isCurrent && total != null
                              ? '${_clock(position)} / ${_clock(total)}'
                              : media.readableSize,
                          style: AppTextStyles.captionXs.copyWith(
                            color: muted,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _clock(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }
}

/// La URL del adjunto exige el Bearer, así que no se puede delegar al navegador
/// del sistema: se baja con Dio (que lo agrega) y recién ahí se abre.
class _DocumentAttachment extends StatefulWidget {
  final MediaAttachment media;
  final String url;
  final bool isOutbound;

  const _DocumentAttachment({
    required this.media,
    required this.url,
    required this.isOutbound,
  });

  @override
  State<_DocumentAttachment> createState() => _DocumentAttachmentState();
}

class _DocumentAttachmentState extends State<_DocumentAttachment> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final client = context.read<ApiClient>();
      final directory = await getTemporaryDirectory();
      final safeName = widget.media.displayName.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      final file = File('${directory.path}/${widget.media.id}_$safeName');

      if (!await file.exists()) {
        await client.dio.download(widget.url, file.path);
      }

      await OpenFilex.open(file.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el archivo.')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.isOutbound ? Colors.white : AppColors.foreground;
    final muted = widget.isOutbound
        ? Colors.white70
        : AppColors.mutedForeground;

    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isOutbound
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file_outlined, size: 28, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.media.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.captionXs.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    [
                      widget.media.kindLabel,
                      if (widget.media.readableSize.isNotEmpty)
                        widget.media.readableSize,
                    ].join(' · '),
                    style: AppTextStyles.captionXs.copyWith(
                      color: muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.download_outlined, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}
