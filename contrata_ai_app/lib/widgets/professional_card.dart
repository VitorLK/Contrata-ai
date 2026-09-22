import 'package:flutter/material.dart';

import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/name_utils.dart';
import '../models/professional_profile_model.dart';

class ProfessionalCard extends StatelessWidget {
  final ProfessionalSummaryModel professional;
  final VoidCallback onTap;

  const ProfessionalCard({
    super.key,
    required this.professional,
    required this.onTap,
  });

  bool get _isAvailableNow => professional.availability == 'Disponível agora';

  @override
  Widget build(BuildContext context) {
    final location = [
      professional.city,
      professional.state,
    ].where((value) => value != null && value.isNotEmpty).join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: professional.photoUrl != null
                            ? NetworkImage(
                                ApiConstants.resolveUrl(professional.photoUrl!),
                              )
                            : null,
                        child: professional.photoUrl == null
                            ? Text(
                                initialsFor(professional.name),
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      if (_isAvailableNow)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          professional.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.near_me_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  _RatingMark(
                    average: professional.ratingAverage,
                    count: professional.ratingCount,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                professional.bio?.trim().isNotEmpty == true
                    ? professional.bio!
                    : 'Este profissional ainda está preparando sua apresentação.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: professional.bio?.trim().isNotEmpty == true
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: professional.skills.take(3).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) => Chip(
                    label: Text(professional.skills[index]),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const Spacer(),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (professional.serviceMode != null) ...[
                    Icon(
                      _modeIcon(professional.serviceMode!),
                      size: 17,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      professional.serviceMode!.label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                  const Spacer(),
                  if (professional.pricingType == PricingType.porHora &&
                      professional.hourlyRate != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'POR HORA',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          'R\$ ${professional.hourlyRate!.toStringAsFixed(0)}/h',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.primaryDark),
                        ),
                      ],
                    )
                  else if (professional.pricingType == PricingType.empreitada &&
                      professional.projectRate != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'EMPREITADA',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          'R\$ ${professional.projectRate!.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.primaryDark),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Valor sob consulta',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _modeIcon(ServiceMode mode) {
    switch (mode) {
      case ServiceMode.presencial:
        return Icons.handyman_outlined;
      case ServiceMode.remoto:
        return Icons.laptop_mac_outlined;
      case ServiceMode.hibrido:
        return Icons.sync_alt;
    }
  }
}

class _RatingMark extends StatelessWidget {
  final double? average;
  final int count;

  const _RatingMark({required this.average, required this.count});

  @override
  Widget build(BuildContext context) {
    if (average == null || count == 0) {
      return Text(
        'NOVO',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.secondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 3),
            Text(
              average!.toStringAsFixed(1),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        Text('$count avaliações', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
