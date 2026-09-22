import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/professional_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../models/professional_profile_model.dart';
import '../../viewmodels/professional_search_viewmodel.dart';
import '../../viewmodels/services_list_viewmodel.dart' show LoadStatus;
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../../widgets/location_selector.dart';
import '../../widgets/professional_card.dart';
import 'professional_public_profile_screen.dart';

class ProfessionalSearchScreen extends StatefulWidget {
  const ProfessionalSearchScreen({super.key});

  @override
  State<ProfessionalSearchScreen> createState() =>
      _ProfessionalSearchScreenState();
}

class _ProfessionalSearchScreenState extends State<ProfessionalSearchScreen> {
  final _queryController = TextEditingController();
  final _resultsKey = GlobalKey();
  String? _category;
  String? _state;
  String? _city;
  final Set<ServiceMode> _serviceModes = {};
  PricingType? _pricingType;
  bool _limitPrice = false;
  double _maxHourlyRate = 200;
  bool _availableNow = false;
  ProfessionalSort _sort = ProfessionalSort.recommended;
  bool _showFilters = false;

  ProfessionalSearchFilters get _filters => ProfessionalSearchFilters(
    query: _queryController.text.trim(),
    category: _category,
    state: _state,
    city: _city,
    serviceModes: Set.unmodifiable(_serviceModes),
    pricingType: _pricingType,
    maxHourlyRate: _limitPrice ? _maxHourlyRate : null,
    availableNow: _availableNow,
    sort: _sort,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() =>
      context.read<ProfessionalSearchViewModel>().search(_filters);

  Future<void> _applyFilters() async {
    FocusScope.of(context).unfocus();
    final shouldFocusResults =
        MediaQuery.sizeOf(context).width < 920 && _showFilters;
    if (shouldFocusResults) {
      setState(() => _showFilters = false);
    }
    await _search();
    if (!mounted || !shouldFocusResults) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resultsContext = _resultsKey.currentContext;
      if (resultsContext == null) return;
      Scrollable.ensureVisible(
        resultsContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: .08,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _queryController.clear();
      _category = null;
      _state = null;
      _city = null;
      _serviceModes.clear();
      _pricingType = null;
      _limitPrice = false;
      _maxHourlyRate = 200;
      _availableNow = false;
      _sort = ProfessionalSort.recommended;
    });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfessionalSearchViewModel>();

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          return RefreshIndicator(
            onRefresh: _search,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                wide ? AppSpacing.xl : AppSpacing.md,
                AppSpacing.lg,
                wide ? AppSpacing.xl : AppSpacing.md,
                48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SearchHero(
                        controller: _queryController,
                        onSubmitted: (_) => _search(),
                        onSearch: _search,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (wide)
                        _buildFilters()
                      else
                        _MobileFiltersPanel(
                          activeCount: _filters.activeFilterCount,
                          expanded: _showFilters,
                          onToggle: () =>
                              setState(() => _showFilters = !_showFilters),
                          onClear: _filters.activeFilterCount == 0
                              ? null
                              : _clearFilters,
                          child: _buildFilters(showCard: false),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      KeyedSubtree(
                        key: _resultsKey,
                        child: _ResultsHeader(
                          count: viewModel.professionals.length,
                          sort: _sort,
                          isLoading: viewModel.status == LoadStatus.loading,
                          onSortChanged: (value) {
                            if (value == null) return;
                            setState(() => _sort = value);
                            _search();
                          },
                          onClear: _filters.activeFilterCount == 0
                              ? null
                              : _clearFilters,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildResults(viewModel, wide),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters({bool showCard = true}) {
    final activeCount = _filters.activeFilterCount;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCard) ...[
          _FilterPanelHeader(
            activeCount: activeCount,
            onClear: activeCount == 0 ? null : _clearFilters,
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
        ],
        const _FilterEyebrow(
          icon: Icons.near_me_outlined,
          label: 'ÁREA E LOCALIZAÇÃO',
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final category = DropdownButtonFormField<String>(
              key: ValueKey(_category),
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Profissão ou área',
                prefixIcon: Icon(Icons.handyman_outlined),
              ),
              hint: const Text('Todas as áreas'),
              items: ProfessionalCatalog.categories
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _category = value),
            );
            final location = LocationSelector(
              key: ValueKey('$_state-$_city'),
              stateCode: _state,
              city: _city,
              allowAll: true,
              onStateChanged: (value) => setState(() => _state = value),
              onCityChanged: (value) => setState(() => _city = value),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: category),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 5, child: location),
                    ],
                  )
                : Column(
                    children: [
                      category,
                      const SizedBox(height: AppSpacing.md),
                      location,
                    ],
                  );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 780;
            final groups = [
              _FilterGroup(
                icon: Icons.storefront_outlined,
                title: 'Atendimento',
                subtitle: 'Onde o serviço acontece',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final mode in ServiceMode.values)
                      _filterChoice(
                        label: mode.label,
                        icon: _serviceModeIcon(mode),
                        selected: _serviceModes.contains(mode),
                        onSelected: (selected) => setState(() {
                          selected
                              ? _serviceModes.add(mode)
                              : _serviceModes.remove(mode);
                        }),
                      ),
                  ],
                ),
              ),
              _FilterGroup(
                icon: Icons.request_quote_outlined,
                title: 'Cobrança',
                subtitle: 'Como o valor é combinado',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final type in PricingType.values)
                      _filterChoice(
                        label: type.label,
                        icon: type == PricingType.porHora
                            ? Icons.schedule_outlined
                            : Icons.inventory_2_outlined,
                        selected: _pricingType == type,
                        onSelected: (selected) => setState(
                          () => _pricingType = selected ? type : null,
                        ),
                      ),
                  ],
                ),
              ),
              _FilterGroup(
                icon: Icons.tune_outlined,
                title: 'Preferências',
                subtitle: 'Disponibilidade e orçamento',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _filterChoice(
                      label: 'Disponível agora',
                      icon: Icons.bolt_outlined,
                      selected: _availableNow,
                      onSelected: (value) =>
                          setState(() => _availableNow = value),
                    ),
                    _filterChoice(
                      label: _limitPrice
                          ? 'Até R\$ ${_maxHourlyRate.toStringAsFixed(0)}'
                          : 'Definir teto',
                      icon: Icons.payments_outlined,
                      selected: _limitPrice,
                      onSelected: (value) =>
                          setState(() => _limitPrice = value),
                    ),
                  ],
                ),
              ),
            ];

            if (!horizontal) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < groups.length; index++) ...[
                    groups[index],
                    if (index < groups.length - 1)
                      const SizedBox(height: AppSpacing.lg),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 10, child: groups[0]),
                const _FilterGroupDivider(),
                Expanded(flex: 9, child: groups[1]),
                const _FilterGroupDivider(),
                Expanded(flex: 9, child: groups[2]),
              ],
            );
          },
        ),
        if (_limitPrice)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      'Faixa máxima',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Text('R\$ 20'),
                    Expanded(
                      child: Slider(
                        min: 20,
                        max: 500,
                        divisions: 24,
                        value: _maxHourlyRate,
                        label: 'R\$ ${_maxHourlyRate.toStringAsFixed(0)}',
                        onChanged: (value) =>
                            setState(() => _maxHourlyRate = value),
                      ),
                    ),
                    Text(
                      'R\$ ${_maxHourlyRate.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                activeCount == 0
                    ? 'Mostrando todos os profissionais'
                    : '$activeCount ${activeCount == 1 ? 'filtro selecionado' : 'filtros selecionados'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (!showCard && activeCount > 0) ...[
              TextButton(onPressed: _clearFilters, child: const Text('Limpar')),
              const SizedBox(width: AppSpacing.sm),
            ],
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: _applyFilters,
              icon: const Icon(Icons.manage_search_outlined, size: 19),
              label: const Text('Ver resultados'),
            ),
          ],
        ),
      ],
    );

    if (!showCard) return content;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: content,
      ),
    );
  }

  Widget _filterChoice({
    required String label,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      avatar: Icon(
        icon,
        size: 17,
        color: selected ? Colors.white : AppColors.textSecondary,
      ),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: onSelected,
    );
  }

  IconData _serviceModeIcon(ServiceMode mode) => switch (mode) {
    ServiceMode.presencial => Icons.storefront_outlined,
    ServiceMode.remoto => Icons.laptop_mac_outlined,
    ServiceMode.hibrido => Icons.sync_alt,
  };

  Widget _buildResults(ProfessionalSearchViewModel viewModel, bool wide) {
    if ((viewModel.status == LoadStatus.loading ||
            viewModel.status == LoadStatus.idle) &&
        viewModel.professionals.isEmpty) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (viewModel.status == LoadStatus.error) {
      return SizedBox(
        height: 320,
        child: ErrorStateView(
          message: viewModel.errorMessage,
          onRetry: _search,
        ),
      );
    }
    if (viewModel.professionals.isEmpty) {
      return SizedBox(
        height: 320,
        child: EmptyStateView(
          icon: Icons.person_search_outlined,
          title: 'Nenhum perfil combina com essa busca',
          message: 'Remova um filtro ou amplie a localização para encontrar mais profissionais.',
          actionLabel: 'Limpar filtros',
          onAction: _clearFilters,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 3
            : (constraints.maxWidth >= 680 ? 2 : 1);
        final gap = AppSpacing.md;
        final cardWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final professional in viewModel.professionals)
              SizedBox(
                width: cardWidth,
                height: 286,
                child: ProfessionalCard(
                  professional: professional,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfessionalPublicProfileScreen(
                        professionalId: professional.userId,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MobileFiltersPanel extends StatelessWidget {
  final int activeCount;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onClear;
  final Widget child;

  const _MobileFiltersPanel({
    required this.activeCount,
    required this.expanded,
    required this.onToggle,
    required this.onClear,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final countLabel = activeCount == 0
        ? 'Use área, região, preço e disponibilidade'
        : '$activeCount ${activeCount == 1 ? 'filtro ativo' : 'filtros ativos'}';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activeCount > 0 ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  expanded: expanded,
                  child: InkWell(
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.tune_outlined,
                              size: 20,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Refinar resultados',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  countLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (onClear != null && !expanded)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Tooltip(
                    message: 'Limpar filtros',
                    child: IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ),
                ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanelHeader extends StatelessWidget {
  final int activeCount;
  final VoidCallback? onClear;

  const _FilterPanelHeader({required this.activeCount, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.tune_outlined,
            size: 21,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Refine sua busca',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'Monte um recorte rápido para encontrar o profissional certo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (activeCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$activeCount ${activeCount == 1 ? 'ativo' : 'ativos'}',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(onPressed: onClear, child: const Text('Limpar')),
        ],
      ],
    );
  }
}

class _FilterEyebrow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FilterEyebrow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: AppColors.primaryDark, letterSpacing: .8),
        ),
      ],
    );
  }
}

class _FilterGroup extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _FilterGroup({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _FilterGroupDivider extends StatelessWidget {
  const _FilterGroupDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SizedBox(height: 92, child: VerticalDivider()),
    );
  }
}

class _SearchHero extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;

  const _SearchHero({
    required this.controller,
    required this.onSubmitted,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _TalentRadarPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 690),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MAPA DE TALENTOS',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: const Color(0xFF9ED3CB)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Encontre quem sabe fazer.',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(color: Colors.white, fontSize: 34),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Busque por nome, profissão ou habilidade e refine pela região em que o serviço acontece.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: const Color(0xFFD6D9DC)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: onSubmitted,
                    decoration: InputDecoration(
                      hintText: 'Ex.: eletricista, designer, manutenção…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: onSearch,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final int count;
  final ProfessionalSort sort;
  final bool isLoading;
  final ValueChanged<ProfessionalSort?> onSortChanged;
  final VoidCallback? onClear;

  const _ResultsHeader({
    required this.count,
    required this.sort,
    required this.isLoading,
    required this.onSortChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count profissionais',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (isLoading) ...[
              const SizedBox(width: AppSpacing.sm),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        DropdownButton<ProfessionalSort>(
          value: sort,
          underline: const SizedBox.shrink(),
          items: ProfessionalSort.values
              .map(
                (item) =>
                    DropdownMenuItem(value: item, child: Text(item.label)),
              )
              .toList(growable: false),
          onChanged: onSortChanged,
        ),
      ],
    );
  }
}

class _TalentRadarPainter extends CustomPainter {
  const _TalentRadarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .88, size.height * .48);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF4C5967).withValues(alpha: .55);
    for (
      var radius = 42.0;
      radius < math.max(size.width, size.height);
      radius += 42
    ) {
      canvas.drawCircle(center, radius, paint);
    }
    final dotPaint = Paint()..color = AppColors.accent;
    canvas.drawCircle(center.translate(-44, -38), 5, dotPaint);
    canvas.drawCircle(
      center.translate(34, 24),
      4,
      dotPaint..color = const Color(0xFF68A89F),
    );
    canvas.drawCircle(
      center.translate(-12, 72),
      3,
      dotPaint..color = const Color(0xFFBFC7CF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
