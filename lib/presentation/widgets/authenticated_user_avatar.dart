import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/models/user_model.dart';

/// Avatar privado del usuario. Laravel exige el Bearer también para descargar
/// la imagen, por lo que no basta con un NetworkImage convencional.
class AuthenticatedUserAvatar extends StatefulWidget {
  const AuthenticatedUserAvatar({
    super.key,
    required this.user,
    this.size = 72,
    this.ringColor,
    this.backgroundColor,
    this.foregroundColor,
  });

  final UserModel user;
  final double size;
  final Color? ringColor;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  State<AuthenticatedUserAvatar> createState() =>
      _AuthenticatedUserAvatarState();
}

class _AuthenticatedUserAvatarState extends State<AuthenticatedUserAvatar> {
  late Future<Map<String, String>> _headers;

  @override
  void initState() {
    super.initState();
    _headers = context.read<ApiClient>().mediaHeaders();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedUserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.avatarUrl != widget.user.avatarUrl) {
      _headers = context.read<ApiClient>().mediaHeaders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderWidth = widget.ringColor == null ? 0.0 : 2.0;

    return Container(
      width: widget.size,
      height: widget.size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: widget.ringColor == null
            ? null
            : Border.all(color: widget.ringColor!, width: borderWidth),
      ),
      child: ClipOval(child: _content()),
    );
  }

  Widget _content() {
    final avatarUrl = widget.user.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) return _fallback();

    final client = context.read<ApiClient>();
    return FutureBuilder<Map<String, String>>(
      future: _headers,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _fallback(showProgress: true);

        return Image.network(
          client.absoluteUrl(avatarUrl),
          headers: snapshot.data,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _fallback(),
        );
      },
    );
  }

  Widget _fallback({bool showProgress = false}) {
    return ColoredBox(
      color: widget.backgroundColor ?? AppColors.brand.withValues(alpha: 0.10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            widget.user.initials,
            style: TextStyle(
              color: widget.foregroundColor ?? AppColors.brand,
              fontSize: widget.size * 0.28,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showProgress)
            SizedBox(
              width: widget.size * 0.35,
              height: widget.size * 0.35,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
