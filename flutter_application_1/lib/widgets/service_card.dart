import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/service_model.dart';
import 'status_badge.dart';

class ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final VoidCallback onTap;
  final VoidCallback? onRenew;
  final bool showClientName;
  final bool isRenewing;

  const ServiceCard({
    super.key,
    required this.service,
    required this.onTap,
    this.onRenew,
    this.showClientName = false,
    this.isRenewing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateStamp(date: service.scheduledDate),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          service.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (service.budget != null)
                        Text(
                          'R\$ ${service.budget!.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.primaryDark),
                        )
                      else
                        Text(
                          'A combinar',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      const Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: AppColors.textDisabled,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (service.category != null)
                    Chip(
                      avatar: const Icon(Icons.handyman_outlined, size: 15),
                      label: Text(service.category!),
                    ),
                  Chip(
                    avatar: const Icon(Icons.place_outlined, size: 15),
                    label: Text(service.locationLabel),
                  ),
                  StatusBadge(status: service.status),
                  if (showClientName && service.clientName != null)
                    Chip(
                      avatar: const Icon(Icons.person_outline, size: 15),
                      label: Text(service.clientName!),
                    ),
                  if (!showClientName && service.applicationCount > 0)
                    Chip(
                      label: Text(
                        '${service.applicationCount} ${service.applicationCount == 1 ? 'candidato' : 'candidatos'}',
                      ),
                    ),
                ],
              ),
              if (service.needsOpenConfirmation && onRenew != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'A data passou. Confirme se a oportunidade continua aberta.',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.tonal(
                        onPressed: isRenewing ? null : onRenew,
                        child: Text(isRenewing ? 'Aguarde…' : 'Manter aberto'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateStamp extends StatelessWidget {
  final DateTime date;

  const _DateStamp({required this.date});

  @override
  Widget build(BuildContext context) {
    const weekdays = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isToday ? AppColors.primary : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            isToday ? 'HOJE' : weekdays[date.weekday - 1],
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isToday ? Colors.white70 : AppColors.primaryDark,
            ),
          ),
          Text(
            date.day.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: isToday ? Colors.white : AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
