import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/application_model.dart';
import '../services/application_repository.dart';
import '../services/service_repository.dart';
import 'services_list_viewmodel.dart' show LoadStatus;

/// ViewModel da lista de candidaturas — usada tanto para "candidatos de um
/// serviço" (visão do cliente, Etapa 10) quanto para "minhas candidaturas"
/// (visão do profissional, Etapa 13), seguindo o mesmo padrão dual do
/// ServicesListViewModel.
class ApplicationsViewModel extends ChangeNotifier {
  final ServiceRepository serviceRepository;
  final ApplicationRepository applicationRepository;

  ApplicationsViewModel({
    required this.serviceRepository,
    required this.applicationRepository,
  });

  LoadStatus status = LoadStatus.idle;
  List<ApplicationModel> applications = [];
  String? errorMessage;

  // Guardado para permitir recarregar a lista depois de aceitar/recusar
  // sem o widget precisar passar o serviceId de novo a cada chamada.
  String? _serviceId;

  Future<void> loadForService(String serviceId) async {
    _serviceId = serviceId;
    status = LoadStatus.loading;
    notifyListeners();

    try {
      applications = await serviceRepository.listApplications(serviceId);
      status = LoadStatus.loaded;
    } on ApiException catch (e) {
      errorMessage = e.message;
      status = LoadStatus.error;
    } catch (_) {
      errorMessage = 'Não foi possível carregar os candidatos.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> loadMine() async {
    // Fora do contexto de "candidatos do meu serviço" — não faz sentido
    // aceitar/recusar a própria candidatura a partir daqui.
    _serviceId = null;
    status = LoadStatus.loading;
    notifyListeners();

    try {
      applications = await applicationRepository.listMine();
      status = LoadStatus.loaded;
    } on ApiException catch (e) {
      errorMessage = e.message;
      status = LoadStatus.error;
    } catch (_) {
      errorMessage = 'Não foi possível carregar suas candidaturas.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> accept(String applicationId) async {
    final serviceId = _serviceId;
    if (serviceId == null) return;
    await serviceRepository.acceptApplication(
      serviceId: serviceId,
      applicationId: applicationId,
    );
    await loadForService(serviceId);
  }

  Future<void> reject(String applicationId) async {
    final serviceId = _serviceId;
    if (serviceId == null) return;
    await serviceRepository.rejectApplication(
      serviceId: serviceId,
      applicationId: applicationId,
    );
    await loadForService(serviceId);
  }
}
