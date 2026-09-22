import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/service_model.dart';
import '../models/professional_profile_model.dart';
import '../services/service_repository.dart';

enum LoadStatus { idle, loading, loaded, error }

/// ViewModel usada tanto para a lista de serviços abertos (visão do
/// profissional) quanto para "meus serviços" (visão do cliente).
class ServicesListViewModel extends ChangeNotifier {
  final ServiceRepository serviceRepository;

  ServicesListViewModel({required this.serviceRepository});

  LoadStatus status = LoadStatus.idle;
  List<ServiceModel> services = [];
  String? errorMessage;

  String queryText = '';
  String? category;
  ServiceDiscoveryStatus discoveryStatus = ServiceDiscoveryStatus.abertos;
  ServiceDateScope dateScope = ServiceDateScope.hoje;
  String? state;
  String? city;
  ServiceMode? serviceMode;
  double? minBudget;
  double? maxBudget;
  bool isRenewing = false;

  Future<void> loadOpenServices() => loadAvailableServices();

  Future<void> loadAvailableServices() {
    return _load(
      () => serviceRepository.listServices(
        queryText: queryText,
        category: category,
        status: discoveryStatus.apiValue,
        dateScope: dateScope.apiValue,
        state: state,
        city: city,
        serviceMode: serviceMode,
        minBudget: minBudget,
        maxBudget: maxBudget,
      ),
    );
  }

  Future<void> loadMyServices() => _load(serviceRepository.listMyServices);

  Future<void> _load(Future<List<ServiceModel>> Function() fetch) async {
    status = LoadStatus.loading;
    notifyListeners();

    try {
      services = await fetch();
      status = LoadStatus.loaded;
    } on ApiException catch (e) {
      errorMessage = e.message;
      status = LoadStatus.error;
    } catch (_) {
      errorMessage = 'Não foi possível carregar os serviços.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> applyToService(String serviceId, {String? message}) {
    return serviceRepository.applyToService(
      serviceId: serviceId,
      message: message,
    );
  }

  Future<void> setQuickFilters({
    ServiceDiscoveryStatus? status,
    ServiceDateScope? period,
    String? search,
  }) {
    if (status != null) discoveryStatus = status;
    if (period != null) dateScope = period;
    if (search != null) queryText = search.trim();
    notifyListeners();
    return loadAvailableServices();
  }

  Future<void> applyAdvancedFilters({
    String? selectedCategory,
    String? selectedState,
    String? selectedCity,
    ServiceMode? selectedServiceMode,
    double? selectedMinBudget,
    double? selectedMaxBudget,
  }) {
    category = selectedCategory;
    state = selectedState;
    city = selectedCity;
    serviceMode = selectedServiceMode;
    minBudget = selectedMinBudget;
    maxBudget = selectedMaxBudget;
    notifyListeners();
    return loadAvailableServices();
  }

  Future<void> applyDiscoveryFilters({
    required ServiceDateScope selectedDateScope,
    required ServiceDiscoveryStatus selectedStatus,
    String? selectedCategory,
    String? selectedState,
    String? selectedCity,
    ServiceMode? selectedServiceMode,
    double? selectedMinBudget,
    double? selectedMaxBudget,
  }) {
    dateScope = selectedDateScope;
    discoveryStatus = selectedStatus;
    category = selectedCategory;
    state = selectedState;
    city = selectedCity;
    serviceMode = selectedServiceMode;
    minBudget = selectedMinBudget;
    maxBudget = selectedMaxBudget;
    notifyListeners();
    return loadAvailableServices();
  }

  Future<void> clearAdvancedFilters() {
    category = null;
    state = null;
    city = null;
    serviceMode = null;
    minBudget = null;
    maxBudget = null;
    notifyListeners();
    return loadAvailableServices();
  }

  int get advancedFilterCount => [
    category,
    state,
    serviceMode,
    minBudget,
    maxBudget,
  ].where((value) => value != null).length;

  String get discoverySummary {
    final parts = <String>[dateScope.label, discoveryStatus.label];
    if (category != null) parts.add(category!);
    if (city != null) parts.add(city!);
    return parts.join(' · ');
  }

  Future<void> renewService(String serviceId) async {
    isRenewing = true;
    notifyListeners();
    try {
      await serviceRepository.renewService(serviceId);
      await loadMyServices();
    } finally {
      isRenewing = false;
      notifyListeners();
    }
  }
}

enum ServiceDiscoveryStatus { abertos, fechados, todos }

extension ServiceDiscoveryStatusX on ServiceDiscoveryStatus {
  String get label => switch (this) {
    ServiceDiscoveryStatus.abertos => 'Abertos',
    ServiceDiscoveryStatus.fechados => 'Fechados',
    ServiceDiscoveryStatus.todos => 'Todos',
  };

  String get apiValue => switch (this) {
    ServiceDiscoveryStatus.abertos => 'aberto',
    ServiceDiscoveryStatus.fechados => 'fechados',
    ServiceDiscoveryStatus.todos => 'todos',
  };
}

enum ServiceDateScope { hoje, proximos, todos }

extension ServiceDateScopeX on ServiceDateScope {
  String get label => switch (this) {
    ServiceDateScope.hoje => 'Hoje',
    ServiceDateScope.proximos => 'Próximos',
    ServiceDateScope.todos => 'Todas as datas',
  };

  String get apiValue => switch (this) {
    ServiceDateScope.hoje => 'hoje',
    ServiceDateScope.proximos => 'proximos',
    ServiceDateScope.todos => 'todos',
  };
}
