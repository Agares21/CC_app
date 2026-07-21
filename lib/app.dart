import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/session_controller.dart';
import 'shared/presentation/app_shell.dart';

class ContactCenterApp extends ConsumerWidget {
  const ContactCenterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return MaterialApp(
      title: 'Cloud Contact Center',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: session.isBootstrapping
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : session.user == null
          ? const LoginPage()
          : AppShell(user: session.user!),
    );
  }
}
