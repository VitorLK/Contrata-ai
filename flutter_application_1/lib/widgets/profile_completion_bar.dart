import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Indicador "Perfil completo: XX%" — pensado para incentivar o
/// profissional a preencher as informações do próprio perfil, sem travar
/// nenhuma funcionalidade caso ele não esteja em 100%.
class ProfileCompletionBar extends StatelessWidget {
  final int percentage;
  final List<String> missingItems;

  const ProfileCompletionBar({
    super.key,
    required this.percentage,
    this.missingItems = const [],
  });

  Color get _color {
    if (percentage >= 100) return AppColors.success;
    if (percentage >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FORÇA DO PERFIL',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            percentage >= 100
                ? 'Perfil pronto para gerar confiança.'
                : 'Perfis completos aparecem melhor na comparação.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (missingItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final item in missingItems.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.circle_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
