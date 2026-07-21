import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/admin/presentation/admin_page.dart';
import '../../features/agent/presentation/agent_dashboard_page.dart';
import '../../features/agent/presentation/agent_history_page.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/chats/presentation/chats_page.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.user});
  final AppUser user;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final admin = widget.user.isAdmin;
    final pages = admin
        ? const [ChatsPage(), AdminPage()]
        : const [AgentDashboardPage(), ChatsPage(), AgentHistoryPage()];
    final destinations = admin
        ? const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'Administrar',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              label: 'Historial',
            ),
          ];

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 62,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'CC',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        title: const SizedBox(
          height: 38,
          child: TextField(
            style: TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: Colors.white70, size: 19),
              hintText: 'Buscar usuarios, chats y más...',
              hintStyle: TextStyle(color: Colors.white60, fontSize: 12),
              fillColor: Color(0xFF195A87),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.notifications_none),
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(sessionControllerProvider.notifier).logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(widget.user.fullName)),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: IndexedStack(index: index, children: pages),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.primary,
        indicatorColor: Colors.white,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white70,
          ),
        ),
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: destinations
            .map(
              (item) => NavigationDestination(
                icon: IconTheme(
                  data: const IconThemeData(color: Colors.white70),
                  child: item.icon,
                ),
                selectedIcon: IconTheme(
                  data: const IconThemeData(color: AppTheme.primary),
                  child: item.selectedIcon ?? item.icon,
                ),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
