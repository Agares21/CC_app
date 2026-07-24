import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:cloud_api_cc/data/api/devices_api.dart';

const _chatChannelId = 'chats';
const _chatChannelName = 'Chats';
const _chatChannelDescription = 'Mensajes nuevos de clientes en WhatsApp';

/// Firebase ejecuta esta función en otro isolate cuando Android recibe un
/// mensaje de datos con la app en background o cerrada.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await AndroidChatNotifications.handleRemoteMessage(message);
  } catch (e) {
    debugPrint('Push background: no se pudo procesar el evento. $e');
  }
}

/// Notificación local con id estable por conversación.
///
/// FCM entrega sólo datos. AndroidChatNotifications dibuja el aviso y puede
/// retirarlo más tarde con el mismo id cuando otro agente toma el chat.
class AndroidChatNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_chat'),
  );

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _chatChannelId,
      _chatChannelName,
      channelDescription: _chatChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_stat_chat',
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.private,
    ),
  );

  static Future<void> initialize({
    DidReceiveNotificationResponseCallback? onTap,
  }) async {
    if (_initialized) return;

    await _plugin.initialize(
      settings: _initializationSettings,
      onDidReceiveNotificationResponse: onTap,
    );
    _initialized = true;
  }

  static Future<void> handleRemoteMessage(RemoteMessage message) async {
    await initialize();

    final conversationId = _conversationIdFromData(message.data);
    if (conversationId == null) return;

    final event = message.data['event'];
    if (event == 'conversation_claimed') {
      await cancel(conversationId);
      return;
    }

    if (event != 'new_chat' && event != 'new_message') return;

    await _plugin.show(
      id: notificationIdForConversation(conversationId),
      title: message.data['title'] ?? 'Nuevo mensaje de WhatsApp',
      body: message.data['body'] ?? 'Tienes un mensaje nuevo.',
      notificationDetails: _notificationDetails,
      payload: jsonEncode({'conversation_id': conversationId}),
    );
  }

  static Future<void> cancel(int conversationId) {
    return _plugin.cancel(id: notificationIdForConversation(conversationId));
  }

  /// Android 13+ exige además el permiso del sistema para poder mostrar los
  /// avisos locales. Se solicita al iniciar una sesión autenticada.
  static Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    return await android?.requestNotificationsPermission() ?? true;
  }

  static Future<NotificationAppLaunchDetails?> getLaunchDetails() {
    return _plugin.getNotificationAppLaunchDetails();
  }
}

/// Android usa un entero de 32 bits como id. Los ids normales de la base de
/// datos entran directamente; la máscara mantiene el contrato si crecen mucho.
int notificationIdForConversation(int conversationId) {
  final id = conversationId & 0x7fffffff;
  return id == 0 ? 1 : id;
}

int? conversationIdFromNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;

  try {
    final value = jsonDecode(payload);
    if (value is Map<String, dynamic>) {
      return int.tryParse('${value['conversation_id']}');
    }
    if (value is num || value is String) {
      return int.tryParse('$value');
    }
  } catch (_) {
    // Compatibilidad con un payload antiguo que sólo guardara el número.
    return int.tryParse(payload);
  }

  return null;
}

int? _conversationIdFromData(Map<String, dynamic> data) {
  return int.tryParse('${data['conversation_id']}');
}

/// Registro FCM, interacción con avisos y puente hacia la navegación.
class PushService {
  PushService({required DevicesApi devicesApi}) : _devicesApi = devicesApi;

  final DevicesApi _devicesApi;
  final _conversationTaps = StreamController<int>.broadcast();
  final _foregroundMessages = StreamController<void>.broadcast();

  Stream<int> get onConversationTapped => _conversationTaps.stream;
  Stream<void> get onForegroundMessage => _foregroundMessages.stream;

  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  bool _disponible = false;
  String? _tokenActual;
  int? _pendingConversationTap;

  bool get disponible => _disponible;

  /// Devuelve el toque que abrió la aplicación antes de que la interfaz
  /// alcanzara a suscribirse. Se consume una sola vez.
  int? takePendingConversationTap() {
    final pending = _pendingConversationTap;
    _pendingConversationTap = null;
    return pending;
  }

  Future<void> init() async {
    if (!Platform.isAndroid) return;

    // Las notificaciones locales funcionan como bandeja visible y conservan
    // el toque que lanzó la app. Se inicializan aun si Firebase no está listo.
    await AndroidChatNotifications.initialize(
      onTap: (response) {
        final id = conversationIdFromNotificationPayload(response.payload);
        if (id != null) _emitConversationTap(id);
      },
    );

    final localLaunch = await AndroidChatNotifications.getLaunchDetails();
    if (localLaunch?.didNotificationLaunchApp ?? false) {
      final id = conversationIdFromNotificationPayload(
        localLaunch?.notificationResponse?.payload,
      );
      if (id != null) _pendingConversationTap = id;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await Firebase.initializeApp();
      _disponible = true;
    } catch (e) {
      debugPrint(
        'Push: Firebase no arrancó, la app sigue sin notificaciones remotas. $e',
      );
      return;
    }

    // Compatibilidad con avisos FCM antiguos que aún tengan notification.
    final initialRemote = await FirebaseMessaging.instance.getInitialMessage();
    final initialRemoteId = initialRemote == null
        ? null
        : _conversationIdFromData(initialRemote.data);
    if (_pendingConversationTap == null && initialRemoteId != null) {
      _pendingConversationTap = initialRemoteId;
    }

    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      final id = _conversationIdFromData(message.data);
      if (id != null) _emitConversationTap(id);
    });

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) async {
      await AndroidChatNotifications.handleRemoteMessage(message);
      _foregroundMessages.add(null);
    });
  }

  Future<void> registrar() async {
    if (!Platform.isAndroid) return;

    try {
      final permisoLocal = await AndroidChatNotifications.requestPermission();
      if (!permisoLocal) {
        debugPrint('Push: Android no autorizó mostrar notificaciones.');
        return;
      }

      // La pregunta de Android no depende de que Firebase haya podido
      // inicializar. Si la configuración remota falla, queda registrado en el
      // log, pero el permiso ya fue solicitado como corresponde.
      if (!_disponible) return;

      final permiso = await FirebaseMessaging.instance.requestPermission();
      if (permiso.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push: el usuario negó el permiso de notificaciones.');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _enviarToken(token);
      await _tokenRefresh?.cancel();
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen(
        _enviarToken,
      );
    } catch (e) {
      debugPrint('Push: no se pudo registrar el aparato. $e');
    }
  }

  Future<void> darDeBaja() async {
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;

    final token = _tokenActual;
    if (_disponible && token != null) {
      try {
        await _devicesApi.unregister(token);
      } catch (e) {
        debugPrint('Push: no se pudo dar de baja el aparato. $e');
      }
    }

    _tokenActual = null;
    if (Platform.isAndroid) {
      await AndroidChatNotifications._plugin.cancelAll();
    }
  }

  Future<void> _enviarToken(String token) async {
    try {
      await _devicesApi.register(token: token);
      _tokenActual = token;
    } catch (e) {
      debugPrint('Push: el backend no aceptó el token. $e');
    }
  }

  void _emitConversationTap(int id) {
    if (_conversationTaps.hasListener) {
      _conversationTaps.add(id);
    } else {
      _pendingConversationTap = id;
    }
  }

  Future<void> dispose() async {
    await _tokenRefresh?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    await _conversationTaps.close();
    await _foregroundMessages.close();
  }
}
