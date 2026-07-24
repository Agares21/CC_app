import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/presentation/bloc/auth/auth_bloc.dart';
import 'package:cloud_api_cc/data/models/user_model.dart';
import 'package:cloud_api_cc/presentation/widgets/authenticated_user_avatar.dart';

/// Shell principal de la app autenticada.
///
/// Barra principal azul y navegación horizontal superior. Así las secciones
/// importantes permanecen visibles sin ocupar el borde inferior del chat.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _navItems = [
    _NavItem('/chats', Icons.chat_bubble_outline, 'Chats', [
      'administrador',
      'soporte',
    ]),
    _NavItem('/tareas', Icons.assignment_turned_in_outlined, 'Tareas', [
      'administrador',
      'soporte',
    ]),
    _NavItem('/usuarios', Icons.people_outline, 'Usuarios', ['administrador']),
    _NavItem('/horarios', Icons.calendar_month_outlined, 'Horarios', [
      'administrador',
    ]),
    _NavItem('/auditoria', Icons.assignment_outlined, 'Auditoría', [
      'administrador',
    ]),
    _NavItem('/perfil', Icons.person_outline, 'Perfil', [
      'administrador',
      'soporte',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final roleName = user?.role?.name;
        final visibleItems = _navItems
            .where((item) => roleName != null && item.roles.contains(roleName))
            .toList();

        final location = GoRouterState.of(context).matchedLocation;
        int currentIndex = visibleItems.indexWhere(
          (item) => location.startsWith(item.path),
        );
        if (currentIndex < 0) currentIndex = 0;

        return Scaffold(
          appBar: _buildAppBar(context, user),
          body: Column(
            children: [
              if (visibleItems.isNotEmpty)
                _TopNavigationBar(
                  items: visibleItems,
                  currentIndex: currentIndex.clamp(0, visibleItems.length - 1),
                  onSelected: (index) => context.go(visibleItems[index].path),
                ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, UserModel? user) {
    return AppBar(
      title: Row(
        children: [
          // Logo CC amarillo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'CC',
                style: TextStyle(
                  color: AppColors.brandAccentForeground,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Cloud API CC',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ],
      ),
      actions: [
        if (user != null)
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            onSelected: (value) {
              if (value == 'profile') {
                context.go('/perfil');
              } else if (value == 'logout') {
                context.read<AuthBloc>().add(AuthLogoutRequested());
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar con anillo dorado
                  AuthenticatedUserAvatar(
                    user: user,
                    size: 34,
                    ringColor: AppColors.brandAccent,
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brand,
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: Color(0xB3FFFFFF),
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 17),
                    SizedBox(width: 8),
                    Text('Mi perfil'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 16, color: AppColors.destructive),
                    SizedBox(width: 8),
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(color: AppColors.destructive),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _TopNavigationBar extends StatelessWidget {
  const _TopNavigationBar({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brand,
      elevation: 5,
      child: SizedBox(
        height: 58,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 8),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 5),
          itemBuilder: (context, index) {
            final item = items[index];
            final selected = index == currentIndex;
            return Semantics(
              selected: selected,
              button: true,
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minWidth: 76),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: selected
                            ? AppColors.brand
                            : const Color(0xCCFFFFFF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: selected
                              ? AppColors.brand
                              : const Color(0xCCFFFFFF),
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final String label;
  final List<String> roles;
  const _NavItem(this.path, this.icon, this.label, this.roles);
}
