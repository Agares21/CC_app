import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_api_cc/data/api/devices_api.dart';

/// Notificaciones nativas: consigue el token de este aparato y lo deja en el
/// backend, que es quien las envía.
///
/// Vale aclararlo porque se presta a confusión: acá no se manda ninguna
/// notificación. Firebase hace de cartero — le pide a Google Play Services la
/// "dirección" del teléfono (el token de FCM) y avisa cuando llega algo. El
/// envío lo hace Laravel con código propio, por HTTP directo contra FCM
/// (`app/Services/Push/FcmChannel.php`), sin SDK de Google del lado del
/// servidor.
///
/// Hoy solo está cableado Android. iOS necesita además el certificado de APNs
/// y su propio archivo de configuración.
///
/// Todo lo de acá falla en silencio a propósito: sin `google-services.json`, o
/// si el agente niega el permiso, la app tiene que seguir funcionando. Lo
/// único que se pierde es el aviso con la app cerrada — con la app abierta, el
/// polleo de la bandeja ya trae los mensajes nuevos igual.
class PushService {
  PushService({required DevicesApi devicesApi}) : _devicesApi = devicesApi;

  final DevicesApi _devicesApi;

  /// Se dispara cuando el agente toca una notificación, con el id del chat que
  /// hay que abrir. Lo consume la capa de navegación.
  final _conversationTaps = StreamController<int>.broadcast();
  Stream<int> get onConversationTapped => _conversationTaps.stream;

  /// Avisa que entró un mensaje con la app en primer plano, para refrescar sin
  /// esperar al siguiente polleo.
  final _foregroundMessages = StreamController<void>.broadcast();
  Stream<void> get onForegroundMessage => _foregroundMessages.stream;

  StreamSubscription<String>? _tokenRefresh;
  bool _disponible = false;
  String? _tokenActual;

  /// false si Firebase no arrancó (típicamente falta `google-services.json`).
  bool get disponible => _disponible;

  /// Arranca Firebase y engancha los avisos. Se llama una vez, antes de
  /// `runApp`, y no debe tirar: si esto explota, la app no abre.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _disponible = true;
    } catch (e) {
      debugPrint('Push: Firebase no arrancó, la app sigue sin notificaciones. $e');
      return;
    }

    // App cerrada del todo: el mensaje que la abrió queda esperando acá. Se
    // consulta una sola vez, al arrancar.
    final inicial = await FirebaseMessaging.instance.getInitialMessage();
    if (inicial != null) _emitirTap(inicial);

    // App viva pero en segundo plano: Android ya dibujó la notificación y el
    // agente la tocó.
    FirebaseMessaging.onMessageOpenedApp.listen(_emitirTap);

    // App en primer plano. Android no muestra nada en este caso (a propósito:
    // el agente ya está mirando la pantalla), así que solo pedimos refrescar.
    FirebaseMessaging.onMessage.listen((_) => _foregroundMessages.add(null));

    // No registramos un handler de background: el payload que manda el backend
    // trae `notification`, y con eso Android dibuja el aviso solo, sin
    // despertar código Dart. Un handler vacío sería solo ruido.
  }

  /// Registra este aparato para recibir notificaciones. Va después del login:
  /// `POST /devices` necesita el Bearer.
  ///
  /// Conviene llamarlo en cada arranque con sesión abierta, no solo la primera
  /// vez — el token rota (reinstalación, restore de backup, limpieza de datos)
  /// y el endpoint es idempotente.
  Future<void> registrar() async {
    if (!_disponible) return;

    try {
      final permiso = await FirebaseMessaging.instance.requestPermission();

      // denied es una respuesta legítima: el agente no quiere que lo
      // interrumpan. No insistimos ni rompemos nada.
      if (permiso.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push: el usuario negó el permiso de notificaciones.');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _enviarToken(token);

      // El token puede rotar con la app abierta; si pasa, hay que avisarle al
      // backend o las notificaciones dejan de llegar sin que nadie se entere.
      _tokenRefresh?.cancel();
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen(_enviarToken);
    } catch (e) {
      debugPrint('Push: no se pudo registrar el aparato. $e');
    }
  }

  /// Da de baja este aparato. Tiene que correr ANTES del logout, mientras el
  /// Bearer todavía sirve.
  ///
  /// El backend igual borra los registros al cerrar sesión; esto está para que
  /// no queden notificaciones en camino hacia un teléfono que ya cambió de
  /// manos, que en un contact center pasa.
  Future<void> darDeBaja() async {
    _tokenRefresh?.cancel();
    _tokenRefresh = null;

    final token = _tokenActual;
    if (!_disponible || token == null) return;

    try {
      await _devicesApi.unregister(token);
    } catch (e) {
      debugPrint('Push: no se pudo dar de baja el aparato. $e');
    } finally {
      _tokenActual = null;
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

  /// El backend manda `conversation_id` en `data`. Viaja como texto porque FCM
  /// exige que ese diccionario sea plano y de puros strings.
  void _emitirTap(RemoteMessage message) {
    final id = int.tryParse('${message.data['conversation_id']}');
    if (id != null) _conversationTaps.add(id);
  }

  Future<void> dispose() async {
    await _tokenRefresh?.cancel();
    await _conversationTaps.close();
    await _foregroundMessages.close();
  }
}
