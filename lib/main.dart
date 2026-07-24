import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_api_cc/core/notifications/push_service.dart';
import 'package:cloud_api_cc/core/realtime/realtime_service.dart';
import 'package:cloud_api_cc/core/theme/app_theme.dart';
import 'package:cloud_api_cc/core/router/app_router.dart';
import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/api/auth_api.dart';
import 'package:cloud_api_cc/data/api/conversations_api.dart';
import 'package:cloud_api_cc/data/api/devices_api.dart';
import 'package:cloud_api_cc/presentation/bloc/auth/auth_bloc.dart';
import 'package:cloud_api_cc/presentation/bloc/chats/chats_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Instancias compartidas.
  final apiClient = ApiClient();
  final authApi = AuthApi(apiClient);
  final conversationsApi = ConversationsApi(apiClient);
  final pushService = PushService(devicesApi: DevicesApi(apiClient));
  final realtimeService = RealtimeService(client: apiClient);

  // Antes de runApp para no perder el mensaje que abrió la app: si la
  // notificación se tocó con la app cerrada, getInitialMessage() solo lo
  // devuelve una vez. No tira aunque Firebase no esté configurado.
  await pushService.init();

  runApp(
    CloudApiCCApp(
      apiClient: apiClient,
      authApi: authApi,
      conversationsApi: conversationsApi,
      pushService: pushService,
      realtimeService: realtimeService,
    ),
  );
}

/// Punto de entrada de la aplicación Cloud API CC.
class CloudApiCCApp extends StatefulWidget {
  final ApiClient apiClient;
  final AuthApi authApi;
  final ConversationsApi conversationsApi;
  final PushService pushService;
  final RealtimeService realtimeService;

  const CloudApiCCApp({
    super.key,
    required this.apiClient,
    required this.authApi,
    required this.conversationsApi,
    required this.pushService,
    required this.realtimeService,
  });

  @override
  State<CloudApiCCApp> createState() => _CloudApiCCAppState();
}

class _CloudApiCCAppState extends State<CloudApiCCApp> {
  // Los blocs se crean acá, y no dentro del MultiBlocProvider, porque las
  // notificaciones llegan desde fuera del árbol de widgets y hay que poder
  // empujarles eventos sin un BuildContext.
  late final AuthBloc _authBloc;
  late final ChatsBloc _chatsBloc;
  final _suscripciones = <StreamSubscription<void>>[];
  int? _pendingConversationId;
  bool _authNavigationHandled = false;

  @override
  void initState() {
    super.initState();

    _authBloc = AuthBloc(
      authApi: widget.authApi,
      apiClient: widget.apiClient,
      push: widget.pushService,
      realtime: widget.realtimeService,
    )..add(AuthCheckSession());

    _chatsBloc = ChatsBloc(
      api: widget.conversationsApi,
      realtime: widget.realtimeService,
    );

    _suscripciones.addAll([
      widget.pushService.onConversationTapped.listen(_abrirConversacion),
      // Además del aviso local, refrescar en el acto evita esperar al polleo.
      widget.pushService.onForegroundMessage.listen(
        (_) => _chatsBloc.add(ChatsRefreshSilent()),
      ),
    ]);

    // Una notificación puede haber lanzado el proceso antes de que este State
    // y su listener existieran. PushService la conserva hasta este punto.
    _pendingConversationId = widget.pushService.takePendingConversationTap();
  }

  /// Tocar una notificación tiene que dejar al agente en el chat que la
  /// disparó, no en la bandeja.
  void _abrirConversacion(int conversationId) {
    if (_authBloc.state is! AuthAuthenticated) {
      _pendingConversationId = conversationId;
      return;
    }

    routerProvider.go('/chats');
    _chatsBloc.add(ChatsSelectConversation(conversationId));
  }

  bool _abrirPendienteSiCorresponde() {
    final id = _pendingConversationId;
    if (id == null) return false;

    _pendingConversationId = null;
    _abrirConversacion(id);
    return true;
  }

  @override
  void dispose() {
    for (final suscripcion in _suscripciones) {
      suscripcion.cancel();
    }
    _authBloc.close();
    _chatsBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ApiClient>.value(
      value: widget.apiClient,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authBloc),
          BlocProvider.value(value: _chatsBloc),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated && !_authNavigationHandled) {
              _authNavigationHandled = true;
              // La ruta inicial puede haber sido redirigida a /login mientras
              // se leía la sesión segura. Al restaurarla, volver a chats.
              if (!_abrirPendienteSiCorresponde()) {
                routerProvider.go('/chats');
              }
            }

            // Navegar al login cuando se cierra sesión.
            if (state is AuthUnauthenticated) {
              _authNavigationHandled = false;
              routerProvider.go('/login');
            }
          },
          child: MaterialApp.router(
            title: 'Cloud API CC',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            routerConfig: routerProvider,
          ),
        ),
      ),
    );
  }
}
