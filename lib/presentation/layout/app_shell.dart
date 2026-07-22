import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/presentation/bloc/auth/auth_bloc.dart';
import 'package:cloud_api_cc/data/models/user_model.dart';

/// Shell principal de la app autenticada.
///
/// Replica el layout de la web: TopBar azul + BottomNav azul en mobile.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _navItems = [
    _NavItem('/chats', Icons.chat_bubble_outline, 'Chats', ['administrador', 'soporte']),
    _NavItem('/usuarios', Icons.people_outline, 'Usuarios', ['administrador']),
    _NavItem('/horarios', Icons.calendar_month_outlined, 'Horarios', ['administrador']),
    _NavItem('/auditoria', Icons.assignment_outlined, 'Auditoría', ['administrador']),
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
        int currentIndex = visibleItems.indexWhere((item) => location.startsWith(item.path));
        if (currentIndex < 0) currentIndex = 0;

        return Scaffold(
          appBar: _buildAppBar(context, user),
          body: child,
          bottomNavigationBar: visibleItems.length > 1
              ? Container(
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 20,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: BottomNavigationBar(
                    currentIndex: currentIndex.clamp(0, visibleItems.length - 1),
                    onTap: (index) => context.go(visibleItems[index].path),
                    items: visibleItems
                        .map((item) => BottomNavigationBarItem(
                              icon: Icon(item.icon),
                              activeIcon: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(item.icon, color: AppColors.brand),
                              ),
                              label: item.label,
                            ))
                        .toList(),
                  ),
                )
              : null,
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
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
      actions: [
        if (user != null)
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthBloc>().add(AuthLogoutRequested());
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar con anillo dorado
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.brandAccent, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.white,
                      child: Text(
                        user.initials,
                        style: const TextStyle(
                          color: AppColors.brand,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more, size: 18, color: Color(0xB3FFFFFF)),
                ],
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(user.email, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 16, color: AppColors.destructive),
                    SizedBox(width: 8),
                    Text('Cerrar sesión', style: TextStyle(color: AppColors.destructive)),
                  ],
                ),
              ),
            ],
          ),
      ],
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
