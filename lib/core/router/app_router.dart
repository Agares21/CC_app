import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_api_cc/presentation/bloc/auth/auth_bloc.dart';
import 'package:cloud_api_cc/presentation/layout/app_shell.dart';
import 'package:cloud_api_cc/presentation/pages/auth/login_page.dart';
import 'package:cloud_api_cc/presentation/pages/auth/forgot_password_page.dart';
import 'package:cloud_api_cc/presentation/pages/auth/reset_password_page.dart';
import 'package:cloud_api_cc/presentation/pages/auth/accept_invitation_page.dart';
import 'package:cloud_api_cc/presentation/pages/chats/chats_page.dart';
import 'package:cloud_api_cc/presentation/pages/usuarios/usuarios_page.dart';
import 'package:cloud_api_cc/presentation/pages/horarios/horarios_page.dart';
import 'package:cloud_api_cc/presentation/pages/auditoria/auditoria_page.dart';
import 'package:cloud_api_cc/presentation/pages/tasks/tasks_page.dart';
import 'package:cloud_api_cc/presentation/pages/profile/profile_page.dart';

/// Configuración de rutas de la aplicación.
///
/// Usa [GoRouter] con un shell autenticado que muestra el [AppShell]
/// (AppBar + navegación superior) en las rutas protegidas.
final routerProvider = GoRouter(
  initialLocation: '/chats',
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final isAuth = authState is AuthAuthenticated;
    final isAuthRoute =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/forgot-password' ||
        state.matchedLocation == '/reset-password' ||
        state.matchedLocation == '/accept-invitation';

    // Si no está autenticado y no está en una ruta pública, ir al login.
    if (!isAuth && !isAuthRoute) return '/login';
    // Si ya está autenticado y está en el login, ir a chats.
    if (isAuth && state.matchedLocation == '/login') return '/chats';
    return null;
  },
  routes: [
    // — Rutas públicas (sin shell) —
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => ResetPasswordPage(
        token: state.uri.queryParameters['token'] ?? '',
        email: state.uri.queryParameters['email'] ?? '',
      ),
    ),
    GoRoute(
      path: '/accept-invitation',
      builder: (context, state) => AcceptInvitationPage(
        token: state.uri.queryParameters['token'] ?? '',
        email: state.uri.queryParameters['email'] ?? '',
      ),
    ),

    // — Rutas autenticadas (con shell) —
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/chats',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ChatsPage()),
        ),
        GoRoute(
          path: '/tareas',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TasksPage()),
        ),
        GoRoute(
          path: '/perfil',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
        GoRoute(
          path: '/usuarios',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: UsuariosPage()),
        ),
        GoRoute(
          path: '/horarios',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HorariosPage()),
        ),
        GoRoute(
          path: '/auditoria',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AuditoriaPage()),
        ),
      ],
    ),
  ],
);
