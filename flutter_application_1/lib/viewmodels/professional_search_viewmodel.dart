import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/professional_profile_model.dart';
import '../services/professional_repository.dart';
import 'services_list_viewmodel.dart' show LoadStatus;

enum ProfessionalSort {
  recommended,
  bestRated,
  lowestPrice,
  highestPrice,
  name,
}

extension ProfessionalSortX on ProfessionalSort {
  String get apiValue {
    switch (this) {
      case ProfessionalSort.recommended:
        return 'recommended';
      case ProfessionalSort.bestRated:
        return 'rating';
      case ProfessionalSort.lowestPrice:
        return 'price_asc';
      case ProfessionalSort.highestPrice:
        return 'price_desc';
      case ProfessionalSort.name:
        return 'name';
    }
  }

  String get label {
    switch (this) {
      case ProfessionalSort.recommended:
        return 'Mais relevantes';
      case ProfessionalSort.bestRated:
        return 'Melhor avaliados';
      case ProfessionalSort.lowestPrice:
        return 'Menor valor';
      case ProfessionalSort.highestPrice:
        return 'Maior valor';
      case ProfessionalSort.name:
        return 'Nome (A–Z)';
    }
  }
}

class ProfessionalSearchFilters {
  final String query;
  final String? category;
  final String? state;
  final String? city;
  final Set<ServiceMode> serviceModes;
  final PricingType? pricingType;
  final double? maxHourlyRate;
  final bool availableNow;
  final ProfessionalSort sort;

  const ProfessionalSearchFilters({
    this.query = '',
    this.category,
    this.state,
    this.city,
    this.serviceModes = const {},
    this.pricingType,
    this.maxHourlyRate,
    this.availableNow = false,
    this.sort = ProfessionalSort.recommended,
  });

  int get activeFilterCount => [
    query.trim().isNotEmpty,
    category != null,
    state != null,
    city != null,
    serviceModes.isNotEmpty,
    pricingType != null,
    maxHourlyRate != null,
    availableNow,
  ].where((active) => active).length;
}

class ProfessionalSearchViewModel extends ChangeNotifier {
  final ProfessionalRepository professionalRepository;

  ProfessionalSearchViewModel({required this.professionalRepository});

  LoadStatus status = LoadStatus.idle;
  List<ProfessionalSummaryModel> professionals = [];
  String? errorMessage;
  ProfessionalSearchFilters appliedFilters = const ProfessionalSearchFilters();

  Future<void> search([
    ProfessionalSearchFilters filters = const ProfessionalSearchFilters(),
  ]) async {
    appliedFilters = filters;
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await professionalRepository.listProfessionals(
        queryText: filters.query.trim(),
        category: filters.category,
        state: filters.state,
        city: filters.city,
        serviceModes: filters.serviceModes.toList(),
        pricingType: filters.pricingType,
        maxHourlyRate: filters.maxHourlyRate,
        availability: filters.availableNow ? 'Disponível agora' : null,
        sort: filters.sort.apiValue,
      );

      // Mantém a experiência correta mesmo enquanto uma API antiga, que
      // ainda ignore os novos parâmetros, estiver em execução.
      professionals = result
          .where((professional) => _matches(professional, filters))
          .toList();
      _sort(professionals, filters.sort);
      status = LoadStatus.loaded;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = LoadStatus.error;
    } catch (_) {
      errorMessage = 'Não foi possível carregar os profissionais.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  bool _matches(
    ProfessionalSummaryModel professional,
    ProfessionalSearchFilters filters,
  ) {
    final query = _normalize(filters.query);
    if (query.isNotEmpty) {
      final searchable = _normalize(
        [
          professional.name,
          professional.bio ?? '',
          ...professional.skills,
        ].join(' '),
      );
      if (!searchable.contains(query)) return false;
    }

    if (filters.category != null &&
        !professional.skills.any(
          (skill) => _normalize(skill) == _normalize(filters.category!),
        )) {
      return false;
    }
    if (filters.state != null &&
        professional.state?.toUpperCase() != filters.state) {
      return false;
    }
    if (filters.city != null &&
        _normalize(professional.city ?? '') != _normalize(filters.city!)) {
      return false;
    }
    if (filters.serviceModes.isNotEmpty &&
        !filters.serviceModes.contains(professional.serviceMode)) {
      return false;
    }
    if (filters.pricingType != null &&
        professional.pricingType != filters.pricingType) {
      return false;
    }
    if (filters.maxHourlyRate != null &&
        (_priceOf(professional) == null ||
            _priceOf(professional)! > filters.maxHourlyRate!)) {
      return false;
    }
    if (filters.availableNow &&
        _normalize(professional.availability ?? '') != 'disponivel agora') {
      return false;
    }
    return true;
  }

  void _sort(List<ProfessionalSummaryModel> items, ProfessionalSort sort) {
    switch (sort) {
      case ProfessionalSort.bestRated:
        items.sort(
          (a, b) => (b.ratingAverage ?? -1).compareTo(a.ratingAverage ?? -1),
        );
      case ProfessionalSort.lowestPrice:
        items.sort(
          (a, b) => (_priceOf(a) ?? double.infinity).compareTo(
            _priceOf(b) ?? double.infinity,
          ),
        );
      case ProfessionalSort.highestPrice:
        items.sort((a, b) => (_priceOf(b) ?? -1).compareTo(_priceOf(a) ?? -1));
      case ProfessionalSort.name:
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case ProfessionalSort.recommended:
        items.sort((a, b) {
          final availabilityComparison = _isAvailableNow(b)
              .compareTo(_isAvailableNow(a));
          if (availabilityComparison != 0) {
            return availabilityComparison;
          }
          final ratingComparison = (b.ratingAverage ?? -1).compareTo(
            a.ratingAverage ?? -1,
          );
          if (ratingComparison != 0) {
            return ratingComparison;
          }
          return b.skills.length.compareTo(a.skills.length);
        });
    }
  }

  int _isAvailableNow(ProfessionalSummaryModel item) =>
      _normalize(item.availability ?? '') == 'disponivel agora' ? 1 : 0;

  double? _priceOf(ProfessionalSummaryModel item) =>
      item.pricingType == PricingType.empreitada
      ? item.projectRate
      : item.hourlyRate;

  String _normalize(String value) {
    const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const plain = 'aaaaaeeeeiiiiooooouuuuc';
    var result = value.trim().toLowerCase();
    for (var i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], plain[i]);
    }
    return result;
  }
}
