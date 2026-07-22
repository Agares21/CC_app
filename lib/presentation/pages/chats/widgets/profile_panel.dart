import 'package:flutter/material.dart';
import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/core/theme/app_text_styles.dart';
import 'package:cloud_api_cc/data/models/conversation_model.dart';

/// Panel de perfil del contacto.
///
/// Muestra avatar grande con fondo dorado, nombre, teléfono,
/// agente asignado y estadísticas de mensajes.
class ProfilePanel extends StatelessWidget {
  final ConversationDetail detail;
  final VoidCallback onBack;

  const ProfilePanel({
    super.key,
    required this.detail,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final contact = detail.contact;
    final initial = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';
    final totalReceived = detail.messages.where((m) => !m.isOutbound).length;
    final totalSent = detail.messages.where((m) => m.isOutbound).length;

    return Column(
      children: [
        // Header con botón back
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: onBack,
                color: AppColors.brand,
              ),
              Text('Perfil del contacto', style: AppTextStyles.headingSm),
            ],
          ),
        ),
        const Divider(height: 1),

        // Contenido
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Banner con avatar grande
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brand, AppColors.brandDark],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.brandAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: AppColors.brandAccentForeground,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        contact.name,
                        style: AppTextStyles.headingLg.copyWith(color: Colors.white),
                      ),
                      if (contact.phone != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            contact.phone!,
                            style: AppTextStyles.caption.copyWith(color: Colors.white70),
                          ),
                        ),
                    ],
                  ),
                ),

                // Info cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _infoCard(
                        icon: Icons.phone,
                        label: 'Teléfono',
                        value: contact.phone ?? 'No disponible',
                      ),
                      const SizedBox(height: 8),
                      _infoCard(
                        icon: Icons.perm_identity,
                        label: 'WhatsApp ID',
                        value: contact.waId,
                      ),
                      if (detail.assignee != null) ...[
                        const SizedBox(height: 8),
                        _infoCard(
                          icon: Icons.support_agent,
                          label: 'Agente asignado',
                          value: detail.assignee!.name,
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Estadísticas
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Estadísticas', style: AppTextStyles.headingSm),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _statItem(
                                      'Recibidos',
                                      totalReceived.toString(),
                                      Icons.call_received,
                                      AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _statItem(
                                      'Enviados',
                                      totalSent.toString(),
                                      Icons.call_made,
                                      AppColors.brand,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.brand),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.captionXs),
                Text(value, style: AppTextStyles.bodySm),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.headingMd.copyWith(color: color)),
          Text(label, style: AppTextStyles.captionXs),
        ],
      ),
    );
  }
}
