import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_api_cc/core/notifications/push_service.dart';
import 'package:cloud_api_cc/core/realtime/realtime_service.dart';
import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/api/auth_api.dart';
import 'package:cloud_api_cc/data/models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckSession extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthLogoutRequested extends AuthEvent {}

/// Mantiene sincronizados el encabezado, el perfil y la sesión almacenada
/// después de editar los datos o la foto.
class AuthUserUpdated extends AuthEvent {
  const AuthUserUpdated(this.userData);

  final Map<String, dynamic> userData;

  @override
  List<Object?> get props => [userData];
}

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Maneja el estado de autenticación global.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthApi _authApi;
  final ApiClient _apiClient;
  final PushService _push;
  final RealtimeService? _realtime;

  AuthBloc({
    required AuthApi authApi,
    required ApiClient apiClient,
    required PushService push,
    RealtimeService? realtime,
  }) : _authApi = authApi,
       _apiClient = apiClient,
       _push = push,
       _realtime = realtime,
       super(AuthInitial()) {
    on<AuthCheckSession>(_onCheckSession);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthUserUpdated>(_onUserUpdated);
  }

  Future<void> _onCheckSession(
    AuthCheckSession event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final token = await _apiClient.getToken();
    if (token == null) {
      emit(AuthUnauthenticated());
      return;
    }

    final cachedUser = await _apiClient.getSavedUser();

    try {
      final data = await _authApi.getUser();
      final userData = data['user'] as Map<String, dynamic>;
      await _apiClient.saveUser(userData);
      emit(AuthAuthenticated(UserModel.fromJson(userData)));
      // Reabrir la app con la sesión ya abierta también es un buen momento para
      // registrar el aparato: el token de FCM pudo haber rotado mientras tanto.
      await _push.registrar();
      await _realtime?.connect();
    } on DioException catch (e) {
      // Un 401 sí significa que la sesión dejó de ser válida. Un corte de red
      // no: en ese caso el soporte sigue entrando con sus datos locales.
      if (e.response?.statusCode == 401) {
        await _apiClient.clearSession();
        emit(AuthUnauthenticated());
        return;
      }

      if (cachedUser != null) {
        emit(AuthAuthenticated(UserModel.fromJson(cachedUser)));
        await _push.registrar();
        await _realtime?.connect();
        return;
      }

      emit(AuthUnauthenticated());
    } catch (_) {
      if (cachedUser != null) {
        emit(AuthAuthenticated(UserModel.fromJson(cachedUser)));
        await _push.registrar();
        await _realtime?.connect();
        return;
      }

      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final data = await _authApi.login(
        email: event.email,
        password: event.password,
      );
      final token = data['token'] as String?;
      if (token != null) await _apiClient.saveToken(token);
      final userData = data['user'] as Map<String, dynamic>;
      await _apiClient.saveUser(userData);
      emit(AuthAuthenticated(UserModel.fromJson(userData)));
      // Después de guardar el Bearer: POST /devices va autenticado.
      await _push.registrar();
      await _realtime?.connect();
    } catch (e) {
      emit(AuthError(_mensajeDeLogin(e)));
      emit(AuthUnauthenticated());
    }
  }

  /// Traduce la falla a algo que el agente pueda accionar.
  ///
  /// Antes todo lo que no fuera un 422 caía en el mismo texto genérico, así que
  /// quedarse sin señal, agotar el límite de intentos o un error del servidor
  /// se veían exactamente igual que escribir mal la contraseña: sin saber cuál
  /// de las cuatro cosas pasó, no hay nada que el usuario pueda hacer distinto.
  String _mensajeDeLogin(Object e) {
    const generico = 'No se pudo iniciar sesión. Intenta de nuevo.';
    if (e is! DioException) return generico;

    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return 'No se pudo conectar con el servidor. Revisá tu conexión a '
            'internet e intentá de nuevo.';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'El servidor tardó demasiado en responder. Revisá tu conexión '
            'e intentá de nuevo.';
      default:
        break;
    }

    final status = e.response?.statusCode;

    // 422 (validación) y 401 son las dos formas en que el backend rechaza las
    // credenciales; el mensaje exacto lo pone él.
    if (status == 422 || status == 401) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final errors = data['errors'];
        if (errors is Map<String, dynamic>) {
          final emailErrors = errors['email'];
          if (emailErrors is List && emailErrors.isNotEmpty) {
            return '${emailErrors.first}';
          }
        }

        final message = data['message'];
        if (message is String && message.isNotEmpty) return message;
      }

      return 'Las credenciales no coinciden con nuestros registros.';
    }

    // El login tiene throttle propio (10 por minuto). Sin este caso, reintentar
    // sólo renueva el bloqueo y el mensaje nunca cambia.
    if (status == 429) {
      final espera = _segundosDeEspera(e.response);

      return espera == null
          ? 'Demasiados intentos. Esperá un minuto antes de volver a intentar.'
          : 'Demasiados intentos. Esperá $espera segundos antes de volver a '
                'intentar.';
    }

    if (status != null && status >= 500) {
      return 'El servidor tuvo un problema ($status). Intentá más tarde.';
    }

    return status == null ? generico : '$generico (error $status)';
  }

  int? _segundosDeEspera(Response<dynamic>? response) {
    final header = response?.headers.value('retry-after');

    return header == null ? null : int.tryParse(header);
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Antes del logout, que es el que revoca el Bearer: después, DELETE
    // /devices daría 401.
    await _push.darDeBaja();
    await _realtime?.disconnect();
    try {
      await _authApi.logout();
    } catch (_) {}
    await _apiClient.clearSession();
    emit(AuthUnauthenticated());
  }

  Future<void> _onUserUpdated(
    AuthUserUpdated event,
    Emitter<AuthState> emit,
  ) async {
    await _apiClient.saveUser(event.userData);
    emit(AuthAuthenticated(UserModel.fromJson(event.userData)));
  }
}
