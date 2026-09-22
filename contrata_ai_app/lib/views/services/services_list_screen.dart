import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/professional_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../models/professional_profile_model.dart';
import '../../viewmodels/services_list_viewmodel.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/location_selector.dart';
import '../../widgets/service_card.dart';
import 'create_service_screen.dart';
import 'service_detail_screen.dart';

class ServicesListScreen extends StatefulWidget {
  final bool isClientView;

  const ServicesListScreen({super.key, required this.isClientView});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() {
    final viewModel = context.read<ServicesListViewModel>();
    return widget.isClientView
        ? viewModel.loadMyServices()
        : viewModel.loadAvailableServices();
  }

  void _search(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        context.read<ServicesListViewModel>().setQuickFilters(search: value);
      }
    });
  }

  Future<void> _renew(String serviceId) async {
    try {
      await context.read<ServicesListViewModel>().renewService(serviceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serviço mantido aberto e visível para hoje.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível renovar: $error')),
      );
    }
  }

  Future<void> _showFilters() async {
    final viewModel = context.read<ServicesListViewModel>();
    String? category = viewModel.category;
    String? state = viewModel.state;
    String? city = viewModel.city;
    ServiceMode? mode = viewModel.serviceMode;
    var dateScope = viewModel.dateScope;
    var discoveryStatus = viewModel.discoveryStatus;
    final minController = TextEditingController(
      text: viewModel.minBudget?.toStringAsFixed(0) ?? '',
    );
    final maxController = TextEditingController(
      text: viewModel.maxBudget?.toStringAsFixed(0) ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Afinar oportunidades',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Quando', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final period in ServiceDateScope.values)
                        ChoiceChip(
                          label: Text(period.label),
                          selected: dateScope == period,
                          onSelected: (_) =>
                              setSheetState(() => dateScope = period),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Situação da oportunidade',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final status in ServiceDiscoveryStatus.values)
                        ChoiceChip(
                          label: Text(status.label),
                          selected: discoveryStatus == status,
                          onSelected: (_) =>
                              setSheetState(() => discoveryStatus = status),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Profissão',
                      prefixIcon: Icon(Icons.handyman_outlined),
                    ),
                    items: ProfessionalCatalog.categories
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setSheetState(() => category = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<ServiceMode>(
                    initialValue: mode,
                    decoration: const InputDecoration(
                      labelText: 'Forma de atendimento',
                      prefixIcon: Icon(Icons.route_outlined),
                    ),
                    items: ServiceMode.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setSheetState(() => mode = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LocationSelector(
                    stateCode: state,
                    city: city,
                    allowAll: true,
                    onStateChanged: (value) =>
                        setSheetState(() => state = value),
                    onCityChanged: (value) => setSheetState(() => city = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Valor mínimo',
                            prefixText: 'R\$ ',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: maxController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Valor máximo',
                            prefixText: 'R\$ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.of(sheetContext).pop();
                            await viewModel.applyDiscoveryFilters(
                              selectedDateScope: ServiceDateScope.hoje,
                              selectedStatus: ServiceDiscoveryStatus.abertos,
                            );
                          },
                          child: const Text('Limpar'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () async {
                            Navigator.of(sheetContext).pop();
                            await viewModel.applyDiscoveryFilters(
                              selectedDateScope: dateScope,
                              selectedStatus: discoveryStatus,
                              selectedCategory: category,
                              selectedState: state,
                              selectedCity: city,
                              selectedServiceMode: mode,
                              selectedMinBudget: _number(minController.text),
                              selectedMaxBudget: _number(maxController.text),
                            );
                          },
                          child: const Text('Aplicar filtros'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    minController.dispose();
    maxController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ServicesListViewModel>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: widget.isClientView
                      ? _ClientHeader(onCreate: _createService)
                      : _DiscoveryHeader(
                          controller: _searchController,
                          viewModel: viewModel,
                          onSearch: _search,
                          onFilters: _showFilters,
                        ),
                ),
                Expanded(child: _buildContent(viewModel)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: widget.isClientView
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Novo serviço'),
              onPressed: _createService,
            )
          : null,
    );
  }

  Widget _buildContent(ServicesListViewModel viewModel) {
    if (viewModel.status == LoadStatus.loading ||
        viewModel.status == LoadStatus.idle) {
      return const LoadingOverlay();
    }
    if (viewModel.status == LoadStatus.error) {
      return ErrorStateView(message: viewModel.errorMessage, onRetry: _load);
    }
    if (viewModel.services.isEmpty) {
      return widget.isClientView
          ? const EmptyStateView(
              icon: Icons.work_outline,
              title: 'Nenhum serviço publicado',
              message: 'Publique sua primeira ordem de serviço.',
            )
          : EmptyStateView(
              icon: Icons.manage_search_outlined,
              title: 'Nenhuma oportunidade neste recorte',
              message: viewModel.dateScope == ServiceDateScope.hoje
                  ? 'Tente ver as próximas datas ou ajustar os filtros.'
                  : 'Altere os filtros para ampliar sua busca.',
            );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
        itemCount: viewModel.services.length,
        itemBuilder: (context, index) {
          final service = viewModel.services[index];
          return ServiceCard(
            service: service,
            showClientName: !widget.isClientView,
            isRenewing: viewModel.isRenewing,
            onRenew: widget.isClientView && service.needsOpenConfirmation
                ? () => _renew(service.id)
                : null,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ServiceDetailScreen(
                  serviceId: service.id,
                  initialService: service,
                  canApply: !widget.isClientView,
                  isClientView: widget.isClientView,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createService() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateServiceScreen()),
    );
    if (created == true) _load();
  }
}

class _ClientHeader extends StatelessWidget {
  final VoidCallback onCreate;

  const _ClientHeader({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suas ordens de serviço',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Acompanhe candidatos, trabalhos ativos e anúncios que precisam ser renovados.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width >= 720)
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Novo serviço'),
          ),
      ],
    );
  }
}

class _DiscoveryHeader extends StatelessWidget {
  final TextEditingController controller;
  final ServicesListViewModel viewModel;
  final ValueChanged<String> onSearch;
  final VoidCallback onFilters;

  const _DiscoveryHeader({
    required this.controller,
    required this.viewModel,
    required this.onSearch,
    required this.onFilters,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trabalhos disponíveis',
              style: compact
                  ? Theme.of(context).textTheme.headlineSmall
                  : Theme.of(context).textTheme.headlineMedium,
            ),
            if (!compact) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Oportunidades confirmadas pelo contratante, organizadas por data e profissão.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              onChanged: onSearch,
              decoration: const InputDecoration(
                hintText: 'Buscar por título ou descrição',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (compact)
              _MobileFilterSummary(viewModel: viewModel, onTap: onFilters)
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final period in ServiceDateScope.values)
                    ChoiceChip(
                      label: Text(period.label),
                      selected: viewModel.dateScope == period,
                      onSelected: (_) =>
                          viewModel.setQuickFilters(period: period),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  for (final status in ServiceDiscoveryStatus.values)
                    ChoiceChip(
                      label: Text(status.label),
                      selected: viewModel.discoveryStatus == status,
                      onSelected: (_) =>
                          viewModel.setQuickFilters(status: status),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.tune, size: 18),
                    label: Text(
                      viewModel.advancedFilterCount == 0
                          ? 'Mais filtros'
                          : 'Filtros (${viewModel.advancedFilterCount})',
                    ),
                    onPressed: onFilters,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _MobileFilterSummary extends StatelessWidget {
  final ServicesListViewModel viewModel;
  final VoidCallback onTap;

  const _MobileFilterSummary({required this.viewModel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryLight.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 20,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.discoverySummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: AppColors.primaryDark),
                    ),
                    Text(
                      '${viewModel.services.length} ${viewModel.services.length == 1 ? 'oportunidade' : 'oportunidades'} neste recorte',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (viewModel.advancedFilterCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${viewModel.advancedFilterCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const Icon(Icons.tune_rounded, color: AppColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }
}

double? _number(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  return normalized.isEmpty ? null : double.tryParse(normalized);
}
