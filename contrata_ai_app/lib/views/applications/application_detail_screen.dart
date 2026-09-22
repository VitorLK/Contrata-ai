import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/application_model.dart';
import '../../models/professional_profile_model.dart';
import '../../models/service_model.dart';
import '../../viewmodels/application_detail_viewmodel.dart';
import '../../viewmodels/services_list_viewmodel.dart' show LoadStatus;
import '../../widgets/error_state_view.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/service_location_map.dart';
import '../../widgets/status_badge.dart';

class ApplicationDetailScreen extends StatefulWidget {
  final ApplicationModel application;

  const ApplicationDetailScreen({super.key, required this.application});

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  Future<void> _confirmWithdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.undo_rounded, color: AppColors.error, size: 38),
        title: const Text('Retirar candidatura?'),
        content: Text(
          'Você deixará de concorrer ao serviço “${widget.application.serviceTitle ?? 'selecionado'}”. Se a oportunidade continuar aberta, será possível candidatar-se novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Manter candidatura'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sim, retirar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<ApplicationDetailViewModel>().withdraw();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Candidatura retirada com sucesso.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível retirar a candidatura.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ApplicationDetailViewModel>();
    final service = viewModel.service;

    Widget body;
    if (viewModel.status == LoadStatus.loading ||
        viewModel.status == LoadStatus.idle) {
      body = const LoadingOverlay();
    } else if (viewModel.status == LoadStatus.error || service == null) {
      body = ErrorStateView(
        message: viewModel.errorMessage,
        onRetry: viewModel.load,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: viewModel.load,
        child: LayoutBuilder(
          builder: (context, viewport) {
            final horizontalPadding = viewport.maxWidth >= 720 ? 32.0 : 16.0;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.md,
                horizontalPadding,
                56,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ServiceApplicationHero(
                        application: widget.application,
                        service: service,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LayoutBuilder(
                        builder: (context, content) {
                          final desktop = content.maxWidth >= 820;
                          final details = _ServiceDetails(service: service);
                          final summary = _ApplicationSummary(
                            application: widget.application,
                            service: service,
                            canWithdraw: viewModel.canWithdraw,
                            isWithdrawing: viewModel.isWithdrawing,
                            onWithdraw: _confirmWithdraw,
                          );
                          if (!desktop) {
                            return Column(
                              children: [
                                summary,
                                const SizedBox(height: AppSpacing.md),
                                details,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: details),
                              const SizedBox(width: AppSpacing.lg),
                              SizedBox(width: 330, child: summary),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da candidatura')),
      body: SafeArea(child: body),
    );
  }
}

class _ServiceApplicationHero extends StatelessWidget {
  final ApplicationModel application;
  final ServiceModel service;

  const _ServiceApplicationHero({
    required this.application,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (service.imageUrl != null)
            Image.network(
              ApiConstants.resolveUrl(service.imageUrl!),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _HeroFallback(),
            )
          else
            const _HeroFallback(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x22144F47), Color(0xEF142F2B)],
                stops: [0.15, 1],
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 20,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                const _HeroPill(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'Sua candidatura',
                ),
                if (service.category != null)
                  _HeroPill(
                    icon: Icons.handyman_outlined,
                    label: service.category!,
                  ),
              ],
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: Colors.white, height: 1.15),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${service.clientName ?? 'Contratante'} · ${service.locationLabel}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withValues(alpha: .82)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.primaryDark)),
        Positioned(
          right: -28,
          top: -28,
          child: Icon(
            Icons.handyman_rounded,
            size: 210,
            color: Colors.white.withValues(alpha: .07),
          ),
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }
}

class _ServiceDetails extends StatelessWidget {
  final ServiceModel service;

  const _ServiceDetails({required this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DetailSection(
          title: 'Sobre o serviço',
          icon: Icons.subject_outlined,
          child: Text(service.description),
        ),
        const SizedBox(height: AppSpacing.md),
        _DetailSection(
          title: 'Informações essenciais',
          icon: Icons.fact_check_outlined,
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _InfoBlock(
                icon: Icons.calendar_today_outlined,
                label: 'Data prevista',
                value: _date(service.scheduledDate),
              ),
              _InfoBlock(
                icon: Icons.payments_outlined,
                label: 'Orçamento',
                value: service.budget == null
                    ? 'A combinar'
                    : _money(service.budget!),
              ),
              _InfoBlock(
                icon: service.serviceMode == ServiceMode.remoto
                    ? Icons.laptop_outlined
                    : Icons.location_on_outlined,
                label: 'Atendimento',
                value: service.locationLabel,
              ),
              _InfoBlock(
                icon: Icons.person_outline,
                label: 'Contratante',
                value: service.clientName ?? 'Não informado',
              ),
            ],
          ),
        ),
        if (service.serviceMode != ServiceMode.remoto) ...[
          const SizedBox(height: AppSpacing.md),
          _DetailSection(
            title: 'Local do serviço',
            icon: Icons.map_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(service.fullLocationLabel),
                if (service.hasCoordinates) ...[
                  const SizedBox(height: AppSpacing.md),
                  ServiceLocationMap(
                    latitude: service.latitude,
                    longitude: service.longitude,
                    height: 230,
                    semanticsLabel:
                        'Mapa da localização aproximada do serviço ${service.title}',
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ApplicationSummary extends StatelessWidget {
  final ApplicationModel application;
  final ServiceModel service;
  final bool canWithdraw;
  final bool isWithdrawing;
  final VoidCallback onWithdraw;

  const _ApplicationSummary({
    required this.application,
    required this.service,
    required this.canWithdraw,
    required this.isWithdrawing,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Situação da candidatura',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ApplicationStatusBadge(status: application.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _ApplicationJourney(status: application.status),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _statusColor(application.status)
                        .withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_statusMessage(application.status)),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Enviada em ${_dateTime(application.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (canWithdraw) ...[
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: isWithdrawing ? null : onWithdraw,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    icon: isWithdrawing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.undo_rounded),
                    label: Text(
                      isWithdrawing ? 'Retirando…' : 'Retirar candidatura',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Disponível enquanto a candidatura estiver em análise e o serviço continuar aberto.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (application.message?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.md),
          _DetailSection(
            title: 'Sua mensagem',
            icon: Icons.chat_bubble_outline,
            child: Text('“${application.message!.trim()}”'),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.work_outline, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Situação do serviço',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      StatusBadge(status: service.status),
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
}

class _ApplicationJourney extends StatelessWidget {
  final ApplicationStatus status;

  const _ApplicationJourney({required this.status});

  @override
  Widget build(BuildContext context) {
    final finalLabel = switch (status) {
      ApplicationStatus.aceito => 'Aprovada',
      ApplicationStatus.recusado => 'Encerrada',
      ApplicationStatus.pendente => 'Resultado',
    };
    final finalColor = status == ApplicationStatus.recusado
        ? AppColors.error
        : AppColors.success;

    return Row(
      children: [
        const _JourneyNode(
          icon: Icons.send_outlined,
          label: 'Enviada',
          color: AppColors.primary,
          active: true,
        ),
        const _JourneyLine(active: true),
        const _JourneyNode(
          icon: Icons.visibility_outlined,
          label: 'Em análise',
          color: AppColors.warning,
          active: true,
        ),
        _JourneyLine(active: status != ApplicationStatus.pendente),
        _JourneyNode(
          icon: status == ApplicationStatus.aceito
              ? Icons.check_rounded
              : status == ApplicationStatus.recusado
              ? Icons.close_rounded
              : Icons.more_horiz_rounded,
          label: finalLabel,
          color: finalColor,
          active: status != ApplicationStatus.pendente,
        ),
      ],
    );
  }
}

class _JourneyNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;

  const _JourneyNode({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: active ? color : AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: active ? color : AppColors.border),
            ),
            child: Icon(
              icon,
              size: 17,
              color: active ? Colors.white : AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active ? AppColors.textPrimary : AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyLine extends StatelessWidget {
  final bool active;

  const _JourneyLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        color: active ? AppColors.primary : AppColors.border,
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoBlock({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryDark),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(ApplicationStatus status) => switch (status) {
  ApplicationStatus.pendente => AppColors.warning,
  ApplicationStatus.aceito => AppColors.success,
  ApplicationStatus.recusado => AppColors.error,
};

String _statusMessage(ApplicationStatus status) => switch (status) {
  ApplicationStatus.pendente => 'O contratante ainda está analisando os profissionais. Você pode retirar a candidatura enquanto aguarda.',
  ApplicationStatus.aceito => 'Você foi escolhido para este serviço. A jornada aparecerá em Trabalho de hoje na data combinada.',
  ApplicationStatus.recusado => 'O contratante selecionou outro profissional. Esta candidatura permanece disponível no seu histórico.',
};

String _date(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _dateTime(DateTime value) {
  final date = value.toLocal();
  final hours = date.hour.toString().padLeft(2, '0');
  final minutes = date.minute.toString().padLeft(2, '0');
  return '${_date(date)} às $hours:$minutes';
}

String _money(double value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
