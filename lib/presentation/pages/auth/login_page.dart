import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/core/theme/app_text_styles.dart';
import 'package:cloud_api_cc/presentation/bloc/auth/auth_bloc.dart';

/// Página de inicio de sesión.
///
/// Replica el diseño web: fondo gradiente azul, tarjeta blanca centrada,
/// logo amarillo "CC", campos de email/password.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Por favor completa todos los campos.');
      return;
    }
    context.read<AuthBloc>().add(
      AuthLoginRequested(email: email, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/chats');
        } else if (state is AuthError) {
          setState(() => _error = state.message);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brand, AppColors.brandDark],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header azul con logo
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.brandAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'CC',
                                  style: TextStyle(
                                    color: AppColors.brandAccentForeground,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Cloud API CC',
                              style: AppTextStyles.headingLg.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Panel de atención por WhatsApp',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Formulario
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Email
                            Text(
                              'Correo electrónico',
                              style: AppTextStyles.label,
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.mail_outline,
                                  size: 18,
                                  color: AppColors.mutedForeground,
                                ),
                                hintText: 'tucorreo@empresa.com',
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Contraseña', style: AppTextStyles.label),
                                // Flexible: los dos textos sueltos no entran en
                                // pantallas angostas ni con el tamaño de fuente
                                // del sistema agrandado, y el Row desborda.
                                Flexible(
                                  child: GestureDetector(
                                    onTap: () => context.go('/forgot-password'),
                                    child: Text(
                                      '¿Olvidaste tu contraseña?',
                                      textAlign: TextAlign.end,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.brand,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 18,
                                  color: AppColors.mutedForeground,
                                ),
                                hintText: '••••••••',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 18,
                                    color: AppColors.mutedForeground,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Error
                            if (_error != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.destructive.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _error!,
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.destructive,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 8),

                            // Submit
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                final loading = state is AuthLoading;
                                return ElevatedButton(
                                  onPressed: loading ? null : _submit,
                                  child: loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Iniciar sesión'),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
