import 'package:flutter/material.dart';
import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/core/theme/app_text_styles.dart';

/// Página de gestión de horarios (solo admin).
class HorariosPage extends StatelessWidget {
  const HorariosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.brand),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Horarios', style: AppTextStyles.headingMd),
                      Text('Turnos de atenci\u00f3n de agentes', style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 48, color: AppColors.mutedForeground.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    Text('Conecta con tu API para ver los horarios.', style: AppTextStyles.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
