import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/professional_profile_model.dart';
import '../models/availability_model.dart';
import '../services/professional_repository.dart';
import 'services_list_viewmodel.dart' show LoadStatus;

/// ViewModel da tela "Meu Perfil" (profissional) — carrega o perfil
/// completo (dados + completude + portfólio) e expõe as ações de salvar
/// texto, enviar foto e gerenciar o portfólio.
class ProfessionalProfileViewModel extends ChangeNotifier {
  final ProfessionalRepository professionalRepository;

  ProfessionalProfileViewModel({required this.professionalRepository});

  LoadStatus status = LoadStatus.idle;
  ProfessionalProfileModel? profile;
  String? errorMessage;

  bool isSaving = false;
  bool isUploadingPhoto = false;
  bool isUploadingPortfolioItem = false;

  Future<void> load() async {
    status = LoadStatus.loading;
    notifyListeners();

    try {
      profile = await professionalRepository.getMyProfile();
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

  Future<void> save({
    required String bio,
    required List<String> skills,
    double? hourlyRate,
    required PricingType pricingType,
    double? projectRate,
    required String experience,
    required String city,
    required String state,
    ServiceMode? serviceMode,
    required String availability,
    required String phone,
    ProfessionalAvailabilityModel? availabilitySchedule,
  }) async {
    isSaving = true;
    notifyListeners();
    try {
      profile = await professionalRepository.updateMyProfile(
        bio: bio,
        skills: skills,
        hourlyRate: hourlyRate,
        pricingType: pricingType,
        projectRate: projectRate,
        experience: experience,
        city: city,
        state: state,
        serviceMode: serviceMode,
        availability: availability,
        phone: phone,
      );
      if (availabilitySchedule != null) {
        await professionalRepository.updateMyAvailability(
          availabilitySchedule,
        );
        profile = await professionalRepository.getMyProfile();
      }
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    isUploadingPhoto = true;
    notifyListeners();
    try {
      await professionalRepository.uploadPhoto(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      );
      await load();
    } finally {
      isUploadingPhoto = false;
      notifyListeners();
    }
  }

  Future<void> addPortfolioItem({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    isUploadingPortfolioItem = true;
    notifyListeners();
    try {
      await professionalRepository.addPortfolioItem(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      );
      await load();
    } finally {
      isUploadingPortfolioItem = false;
      notifyListeners();
    }
  }

  Future<void> deletePortfolioItem(String itemId) async {
    await professionalRepository.deletePortfolioItem(itemId);
    await load();
  }
}
