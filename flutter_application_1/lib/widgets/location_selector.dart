import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/location_model.dart';
import '../viewmodels/location_viewmodel.dart';

class LocationSelector extends StatefulWidget {
  final String? stateCode;
  final String? city;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onCityChanged;
  final bool required;
  final bool allowAll;

  const LocationSelector({
    super.key,
    required this.stateCode,
    required this.city,
    required this.onStateChanged,
    required this.onCityChanged,
    this.required = false,
    this.allowAll = false,
  });

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  String? _requestedState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestCitiesIfNeeded();
  }

  @override
  void didUpdateWidget(covariant LocationSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stateCode != widget.stateCode) _requestCitiesIfNeeded();
  }

  void _requestCitiesIfNeeded() {
    final stateCode = widget.stateCode;
    if (stateCode == null ||
        stateCode.isEmpty ||
        stateCode == _requestedState) {
      return;
    }
    _requestedState = stateCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LocationViewModel>().loadCities(stateCode);
    });
  }

  Future<void> _changeState(String? value) async {
    widget.onStateChanged(value);
    widget.onCityChanged(null);
    if (value != null) {
      _requestedState = value;
      await context.read<LocationViewModel>().loadCities(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = context.watch<LocationViewModel>();
    final cities = locations.citiesFor(widget.stateCode);
    final isLoading = locations.isLoading(widget.stateCode);
    final error = locations.errorFor(widget.stateCode);

    final stateField = DropdownButtonFormField<String>(
      initialValue: widget.stateCode,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: widget.allowAll ? 'Estado' : 'Estado (UF)',
        prefixIcon: const Icon(Icons.map_outlined),
      ),
      hint: Text(widget.allowAll ? 'Todos os estados' : 'Selecione'),
      items: BrazilLocations.states
          .map(
            (state) =>
                DropdownMenuItem(value: state.code, child: Text(state.label)),
          )
          .toList(growable: false),
      validator: widget.required
          ? (value) => value == null ? 'Selecione o estado' : null
          : null,
      onChanged: _changeState,
    );

    Widget cityField;
    if (isLoading) {
      cityField = const TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Cidade',
          prefixIcon: Icon(Icons.location_city_outlined),
          suffixIcon: Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    } else {
      final selectedCity = cities.contains(widget.city) ? widget.city : null;
      cityField = DropdownMenu<String>(
        key: ValueKey('${widget.stateCode}-$selectedCity-${cities.length}'),
        initialSelection: selectedCity,
        enabled: widget.stateCode != null && cities.isNotEmpty,
        expandedInsets: EdgeInsets.zero,
        enableFilter: true,
        enableSearch: true,
        requestFocusOnTap: true,
        menuHeight: 340,
        label: Text(
          widget.stateCode == null ? 'Escolha o estado primeiro' : 'Cidade',
        ),
        leadingIcon: const Icon(Icons.location_city_outlined),
        hintText: widget.allowAll
            ? 'Todas as cidades'
            : 'Selecione ou pesquise',
        dropdownMenuEntries: cities
            .map((city) => DropdownMenuEntry<String>(value: city, label: city))
            .toList(growable: false),
        onSelected: widget.onCityChanged,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = constraints.maxWidth >= 560
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: stateField),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 3, child: cityField),
                ],
              )
            : Column(
                children: [
                  stateField,
                  const SizedBox(height: AppSpacing.md),
                  cityField,
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            fields,
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      error,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.error),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.stateCode == null
                        ? null
                        : () => locations.loadCities(
                            widget.stateCode!,
                            force: true,
                          ),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
