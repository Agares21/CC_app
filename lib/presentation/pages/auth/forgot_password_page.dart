import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/core/theme/app_text_styles.dart';
import 'package:cloud_api_cc/data/api/auth_api.dart';
import 'package:cloud_api_cc/data/api/api_client.dart';

/// Página de recuperación de contraseña.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _error = null; _message = null; _loading = true; });
    try {
      final api = AuthApi(ApiClient());
      final data = await api.forgotPassword(_emailController.text.trim());
      setState(() => _message = data['message'] as String? ?? 'Si el correo está registrado, te enviamos un enlace.');
    } catch (_) {
      setState(() => _error = 'No se pudo procesar la solicitud. Intenta de nuevo.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader('Recuperar contraseña', 'Te enviaremos un enlace a tu correo'),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Correo electrónico', style: AppTextStyles.label),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.mail_outline, size: 18, color: AppColors.mutedForeground),
                              hintText: 'tucorreo@empresa.com',
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_message != null) _infoBox(_message!, AppColors.success),
                          if (_error != null) _infoBox(_error!, AppColors.destructive),
                          ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Enviar enlace de recuperación'),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('Volver a iniciar sesión'),
                            ),
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
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: const BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: AppColors.brandAccent, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('CC', style: TextStyle(color: AppColors.brandAccentForeground, fontWeight: FontWeight.bold, fontSize: 20))),
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.headingLg.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.caption.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _infoBox(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: AppTextStyles.bodySm.copyWith(color: color)),
    );
  }
}
