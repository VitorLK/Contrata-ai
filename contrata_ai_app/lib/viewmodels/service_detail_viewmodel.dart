import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/service_model.dart';
import '../services/service_repository.dart';
import 'services_list_viewmodel.dart' show LoadStatus;

/// ViewModel da tela de detalhe de um serviço — sempre busca o estado mais
/// atual no servidor (Etapa 6 do plano) em vez de depender só do que a
/// lista já tinha carregado, para refletir mudanças de status feitas em
/// outra tela ou por outro usuário.
class ServiceDetailViewModel extends ChangeNotifier {
  final ServiceRepository serviceRepository;

  ServiceDetailViewModel({required this.serviceRepository});

  LoadStatus status = LoadStatus.idle;
  ServiceModel? service;
  String? errorMessage;

  Future<void> load(String serviceId) async {
    status = LoadStatus.loading;
    notifyListeners();

    try {
      service = await serviceRepository.getById(serviceId);
      status = LoadStatus.loaded;
    } on ApiException catch (e) {
      errorMessage = e.message;
      status = LoadStatus.error;
    } catch (_) {
      errorMessage = 'Não foi possível carregar o serviço.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> complete() async {
    final id = service?.id;
    if (id == null) return;
    await serviceRepository.completeService(id);
    await load(id);
  }

  Future<void> cancel() async {
    final id = service?.id;
    if (id == null) return;
    await serviceRepository.cancelService(id);
    await load(id);
  }

  Future<void> submitReview({required int rating, String? comment}) async {
    final id = service?.id;
    if (id == null) return;
    await serviceRepository.submitReview(
      serviceId: id,
      rating: rating,
      comment: comment,
    );
  }
}
