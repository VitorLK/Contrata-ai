import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/application_model.dart';
import '../models/service_model.dart';
import '../services/application_repository.dart';
import '../services/service_repository.dart';
import 'services_list_viewmodel.dart' show LoadStatus;

class ApplicationDetailViewModel extends ChangeNotifier {
  final ApplicationModel application;
  final ServiceRepository serviceRepository;
  final ApplicationRepository applicationRepository;

  ApplicationDetailViewModel({
    required this.application,
    required this.serviceRepository,
    required this.applicationRepository,
  });

  LoadStatus status = LoadStatus.idle;
  ServiceModel? service;
  String? errorMessage;
  bool isWithdrawing = false;

  bool get canWithdraw =>
      application.status == ApplicationStatus.pendente &&
      service?.status == ServiceStatus.aberto;

  Future<void> load() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      service = await serviceRepository.getById(application.serviceId);
      status = LoadStatus.loaded;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = LoadStatus.error;
    } catch (_) {
      errorMessage = 'Não foi possível carregar os detalhes do serviço.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> withdraw() async {
    if (!canWithdraw || isWithdrawing) return;
    isWithdrawing = true;
    notifyListeners();
    try {
      await applicationRepository.withdraw(application.id);
    } finally {
      isWithdrawing = false;
      notifyListeners();
    }
  }
}
