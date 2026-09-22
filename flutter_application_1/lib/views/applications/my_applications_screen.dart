import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/application_model.dart';
import '../../models/service_model.dart';
import '../../services/application_repository.dart';
import '../../services/service_repository.dart';
import '../../viewmodels/application_detail_viewmodel.dart';
import '../../viewmodels/applications_viewmodel.dart';
import '../../viewmodels/services_list_viewmodel.dart' show LoadStatus;
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/status_badge.dart';
import 'application_detail_screen.dart';

enum _ApplicationFilter { todas, pendentes, aceitas, encerradas }

class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  _ApplicationFilter _filter = _ApplicationFilter.todas;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    return context.read<ApplicationsViewModel>().loadMine();
  }

  List<ApplicationModel> _filtered(List<ApplicationModel> applications) {
    return applications
        .where((item) => _matchesApplicationFilter(item, _filter))
        .toList();
  }

  Future<void> _openDetails(ApplicationModel application) async {
    final serviceRepository = context.read<ServiceRepository>();
    final applicationRepository = context.read<ApplicationRepository>();
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ApplicationDetailViewModel(
            application: application,
            serviceRepository: serviceRepository,
            applicationRepository: applicationRepository,
          )..load(),
          child: ApplicationDetailScreen(application: application),
        ),
      ),
    );
    if (removed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ApplicationsViewModel>();

    if (viewModel.status == LoadStatus.loading ||
        viewModel.status == LoadStatus.idle) {
      return const SafeArea(child: LoadingOverlay());
    }
    if (viewModel.status == LoadStatus.error) {
      return SafeArea(
        child: ErrorStateView(message: viewModel.errorMessage, onRetry: _load),
      );
    }

    final applications = viewModel.applications;
    final visible = _filtered(applications);
    final pendingCount = applications
        .where((item) => item.status == ApplicationStatus.pendente)
        .length;
    final acceptedCount = applications
        .where((item) => item.status == ApplicationStatus.aceito)
        .length;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, viewport) {
            final horizontalPadding = viewport.maxWidth >= 720 ? 32.0 : 16.0;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.lg,
                horizontalPadding,
                72,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ApplicationsHeader(
                          total: applications.length,
                          pending: pendingCount,
                          accepted: acceptedCount,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _FilterBar(
                          selected: _filter,
                          applications: applications,
                          onSelected: (filter) =>
                              setState(() => _filter = filter),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (applications.isEmpty)
                          const SizedBox(
                            height: 360,
                            child: EmptyStateView(
                              icon: Icons.assignment_outlined,
                              title: 'Nenhuma candidatura ainda',
                              message: 'Candidate-se a uma oportunidade para acompanhar cada etapa por aqui.',
                            ),
                          )
                        else if (visible.isEmpty)
                          _FilteredEmptyState(filter: _filter)
                        else ...[
                          Text(
                            '${visible.length} ${visible.length == 1 ? 'candidatura' : 'candidaturas'}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          for (final application in visible)
                            _MyApplicationCard(
                              application: application,
                              onTap: () => _openDetails(application),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApplicationsHeader extends StatelessWidget {
  final int total;
  final int pending;
  final int accepted;

  const _ApplicationsHeader({
    required this.total,
    required this.pending,
    required this.accepted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width < 620 ? AppSpacing.md : AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Minhas candidaturas',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Acompanhe as respostas e abra cada candidatura para rever o serviço.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Colors.white.withValues(alpha: .76)),
              ),
            ],
          );
          final numbers = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderMetric(value: '$pending', label: 'em análise'),
              const SizedBox(width: AppSpacing.lg),
              _HeaderMetric(value: '$accepted', label: 'aprovadas'),
              const SizedBox(width: AppSpacing.lg),
              _HeaderMetric(value: '$total', label: 'total'),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minhas candidaturas',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Acompanhe o retorno de cada oportunidade.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(width: double.infinity, child: numbers),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: AppSpacing.xl),
              numbers,
            ],
          );
        },
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: Colors.white),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _ApplicationFilter selected;
  final List<ApplicationModel> applications;
  final ValueChanged<_ApplicationFilter> onSelected;

  const _FilterBar({
    required this.selected,
    required this.applications,
    required this.onSelected,
  });

  int _count(_ApplicationFilter filter) => switch (filter) {
    _ApplicationFilter.todas => applications.length,
    _ =>
      applications
          .where((item) => _matchesApplicationFilter(item, filter))
          .length,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.filter_list_rounded, size: 19),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Filtrar candidaturas',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in _ApplicationFilter.values) ...[
                ChoiceChip(
                  selected: selected == filter,
                  onSelected: (_) => onSelected(filter),
                  label: Text('${_filterLabel(filter)}  ${_count(filter)}'),
                ),
                if (filter != _ApplicationFilter.values.last)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MyApplicationCard extends StatelessWidget {
  final ApplicationModel application;
  final VoidCallback onTap;

  const _MyApplicationCard({required this.application, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _applicationColor(application.status);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  application.serviceTitle ?? 'Serviço',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Publicado por ${application.clientName ?? 'contratante'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ApplicationStatusBadge(status: application.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          if (application.serviceScheduledDate != null)
                            _MetadataChip(
                              icon: Icons.calendar_today_outlined,
                              label: _shortDate(
                                application.serviceScheduledDate!,
                              ),
                            ),
                          _MetadataChip(
                            icon: Icons.location_on_outlined,
                            label: application.serviceLocationLabel,
                          ),
                          if (application.serviceCategory != null)
                            _MetadataChip(
                              icon: Icons.handyman_outlined,
                              label: application.serviceCategory!,
                            ),
                          _MetadataChip(
                            icon: Icons.payments_outlined,
                            label: application.serviceBudget == null
                                ? 'A combinar'
                                : _money(application.serviceBudget!),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            _applicationIcon(application.status),
                            size: 18,
                            color: color,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _applicationHint(application.status),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Ver detalhes',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppColors.primary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: AppColors.primary,
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
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  final _ApplicationFilter filter;

  const _FilteredEmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.filter_alt_off_outlined,
            size: 42,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nenhuma candidatura em “${_filterLabel(filter)}”',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text('Escolha outro filtro para consultar seu histórico.'),
        ],
      ),
    );
  }
}

String _filterLabel(_ApplicationFilter filter) => switch (filter) {
  _ApplicationFilter.todas => 'Todas',
  _ApplicationFilter.pendentes => 'Em análise',
  _ApplicationFilter.aceitas => 'Aprovadas',
  _ApplicationFilter.encerradas => 'Encerradas',
};

bool _matchesApplicationFilter(
  ApplicationModel application,
  _ApplicationFilter filter,
) {
  final serviceEnded =
      application.serviceStatus == ServiceStatus.concluido ||
      application.serviceStatus == ServiceStatus.cancelado;
  return switch (filter) {
    _ApplicationFilter.todas => true,
    _ApplicationFilter.pendentes =>
      application.status == ApplicationStatus.pendente && !serviceEnded,
    _ApplicationFilter.aceitas =>
      application.status == ApplicationStatus.aceito && !serviceEnded,
    _ApplicationFilter.encerradas =>
      application.status == ApplicationStatus.recusado || serviceEnded,
  };
}

Color _applicationColor(ApplicationStatus status) => switch (status) {
  ApplicationStatus.pendente => AppColors.warning,
  ApplicationStatus.aceito => AppColors.success,
  ApplicationStatus.recusado => AppColors.error,
};

IconData _applicationIcon(ApplicationStatus status) => switch (status) {
  ApplicationStatus.pendente => Icons.schedule_rounded,
  ApplicationStatus.aceito => Icons.check_circle_outline,
  ApplicationStatus.recusado => Icons.history_rounded,
};

String _applicationHint(ApplicationStatus status) => switch (status) {
  ApplicationStatus.pendente => 'Aguardando uma decisão do contratante.',
  ApplicationStatus.aceito => 'Você foi selecionado para este serviço.',
  ApplicationStatus.recusado => 'Candidatura mantida no seu histórico.',
};

String _shortDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _money(double value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
