import 'package:flutter/material.dart';

import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/name_utils.dart';
import '../models/application_model.dart';
import '../models/professional_profile_model.dart';
import 'primary_button.dart';
import 'secondary_button.dart';
import 'status_badge.dart';

/// Card de uma candidatura, usado em dois contextos:
/// - "Candidatos do serviço" (visão do cliente): título = nome do
///   profissional; onAccept/onReject presentes.
/// - "Minhas candidaturas" (visão do profissional): título = título do
///   serviço (o profissional já sabe quem é); onAccept/onReject ausentes,
///   já que só o cliente decide sobre a própria candidatura de alguém.
/// Aceitar/recusar só aparece quando a candidatura está pendente E os
/// callbacks foram fornecidos.
class ApplicationCard extends StatefulWidget {
  final ApplicationModel application;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onReject;
  final VoidCallback? onTap;

  const ApplicationCard({
    super.key,
    required this.application,
    this.onAccept,
    this.onReject,
    this.onTap,
  });

  @override
  State<ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<ApplicationCard> {
  bool _isProcessing = false;

  Future<void> _handle(Future<void> Function() action) async {
    setState(() => _isProcessing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    final isPending = application.status == ApplicationStatus.pendente;
    final onAccept = widget.onAccept;
    final onReject = widget.onReject;

    final title =
        application.professionalName ??
        application.serviceTitle ??
        'Candidatura';
    // Quando o título já é o nome do profissional (visão do cliente), a
    // mensagem já dá contexto suficiente. Quando o título é o serviço
    // (visão do profissional), mostra quem publicou.
    final subtitle = application.professionalName == null
        ? application.clientName
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (application.professionalName != null) ...[
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage:
                            application.professionalPhotoUrl != null
                            ? NetworkImage(
                                ApiConstants.resolveUrl(
                                  application.professionalPhotoUrl!,
                                ),
                              )
                            : null,
                        child: application.professionalPhotoUrl == null
                            ? Text(
                                initialsFor(application.professionalName!),
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (application.ratingAverage != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 17,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${application.ratingAverage!.toStringAsFixed(1)} (${application.ratingCount})',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ApplicationStatusBadge(status: application.status),
                    if (widget.onTap != null) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ],
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                'Publicado por: $subtitle',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (application.message != null &&
                application.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(application.message!),
            ],
            if (application.professionalName != null) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _CandidateFact(
                    icon: application.pricingType == PricingType.porHora
                        ? Icons.schedule_outlined
                        : Icons.inventory_2_outlined,
                    label: application.pricingType == PricingType.porHora
                        ? application.hourlyRate == null
                              ? 'Por hora'
                              : 'R\$ ${application.hourlyRate!.toStringAsFixed(0)}/h'
                        : application.projectRate == null
                        ? 'Por empreitada'
                        : 'R\$ ${application.projectRate!.toStringAsFixed(0)} · empreitada',
                  ),
                  for (final skill in application.professionalSkills.take(2))
                    _CandidateFact(icon: Icons.handyman_outlined, label: skill),
                ],
              ),
            ],
            if (isPending && onAccept != null && onReject != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Recusar',
                      isLoading: _isProcessing,
                      onPressed: () => _handle(onReject),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Aceitar',
                      isLoading: _isProcessing,
                      onPressed: () => _handle(onAccept),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CandidateFact extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CandidateFact({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
