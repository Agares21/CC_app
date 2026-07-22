import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_api_cc/core/notifications/push_service.dart';
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
  final bool remember;
  const AuthLoginRequested({required this.email, required this.password, this.remember = false});
  @override
  List<Object?> get props => [email, password, remember];
}

class AuthLogoutRequested extends AuthEvent {}

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

  AuthBloc({required AuthApi authApi, required ApiClient apiClient, required PushService push})
      : _authApi = authApi, _apiClient = apiClient, _push = push, super(AuthInitial()) {
    on<AuthCheckSession>(_onCheckSession);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheckSession(AuthCheckSession event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final token = await _apiClient.getToken();
      if (token == null) { emit(AuthUnauthenticated()); return; }
      final data = await _authApi.getUser();
      emit(AuthAuthenticated(UserModel.fromJson(data['user'] as Map<String, dynamic>)));
      // Reabrir la app con la sesión ya abierta también es un buen momento para
      // registrar el aparato: el token de FCM pudo haber rotado mientras tanto.
      await _push.registrar();
    } catch (_) {
      await _apiClient.clearToken();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final data = await _authApi.login(email: event.email, password: event.password, remember: event.remember);
      final token = data['token'] as String?;
      if (token != null) await _apiClient.saveToken(token);
      emit(AuthAuthenticated(UserModel.fromJson(data['user'] as Map<String, dynamic>)));
      // Después de guardar el Bearer: POST /devices va autenticado.
      await _push.registrar();
    } catch (e) {
      String message = 'No se pudo iniciar sesión. Intenta de nuevo.';
      if (e is DioException && e.response?.statusCode == 422) {
        final errors = e.response?.data?['errors'] as Map<String, dynamic>?;
        final emailErrors = errors?['email'] as List<dynamic>?;
        if (emailErrors != null && emailErrors.isNotEmpty) message = emailErrors.first as String;
      }
      emit(AuthError(message));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    // Antes del logout, que es el que revoca el Bearer: después, DELETE
    // /devices daría 401.
    await _push.darDeBaja();
    try { await _authApi.logout(); } catch (_) {}
    await _apiClient.clearToken();
    emit(AuthUnauthenticated());
  }
}
