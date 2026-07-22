import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/core/theme/app_text_styles.dart';

/// Página para restablecer contraseña.
class ResetPasswordPage extends StatelessWidget {
  final String token;
  final String email;
  const ResetPasswordPage({super.key, required this.token, required this.email});

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
                    Container(
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
                          Text('Restablecer contrase\u00f1a', style: AppTextStyles.headingLg.copyWith(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Elige una nueva contrase\u00f1a', style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Esta funcionalidad estar\u00e1 disponible pr\u00f3ximamente.',
                            style: AppTextStyles.body.copyWith(color: AppColors.mutedForeground),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('Volver a iniciar sesi\u00f3n'),
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
}
