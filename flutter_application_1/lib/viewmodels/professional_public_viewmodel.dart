import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/professional_profile_model.dart';
import '../services/professional_repository.dart';
import 'services_list_viewmodel.dart' show LoadStatus;

/// ViewModel do perfil público de um profissional (visão do cliente).
class ProfessionalPublicViewModel extends ChangeNotifier {
  final ProfessionalRepository professionalRepository;

  ProfessionalPublicViewModel({required this.professionalRepository});

  LoadStatus status = LoadStatus.idle;
  PublicProfessionalProfileModel? profile;
  String? errorMessage;

  Future<void> load(String professionalId) async {
    status = LoadStatus.loading;
    notifyListeners();

    try {
      profile = await professionalRepository.getPublicProfile(professionalId);
      status = LoadStatus.loaded;
    } on ApiException catch (e) {
      errorMessage = e.message;
      status = LoadStatus.error;
    } catch (_) {
      errorMessage = 'Não foi possível carregar o perfil.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }
}
