import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/service_model.dart';
import '../models/professional_profile_model.dart';
import '../services/service_repository.dart';

/// ViewModel do formulário de publicação de um novo serviço (visão do cliente).
class CreateServiceViewModel extends ChangeNotifier {
  final ServiceRepository serviceRepository;

  CreateServiceViewModel({required this.serviceRepository});

  bool isSubmitting = false;
  String? errorMessage;

  Future<ServiceModel?> submit({
    required String title,
    required String description,
    String? category,
    double? budget,
    required DateTime scheduledDate,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    required bool isAllDay,
    required ServiceMode serviceMode,
    String? city,
    String? state,
    String? address,
    double? latitude,
    double? longitude,
    String? serviceId,
    Uint8List? imageBytes,
    String? imageFilename,
    String? imageContentType,
  }) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final service = serviceId == null
          ? await serviceRepository.createService(
              title: title,
              description: description,
              category: category,
              budget: budget,
              scheduledDate: scheduledDate,
              scheduledStart: scheduledStart,
              scheduledEnd: scheduledEnd,
              isAllDay: isAllDay,
              serviceMode: serviceMode,
              city: city,
              state: state,
              address: address,
              latitude: latitude,
              longitude: longitude,
              imageBytes: imageBytes,
              imageFilename: imageFilename,
              imageContentType: imageContentType,
            )
          : await serviceRepository.updateService(
              serviceId: serviceId,
              title: title,
              description: description,
              category: category ?? '',
              budget: budget,
              scheduledDate: scheduledDate,
              scheduledStart: scheduledStart,
              scheduledEnd: scheduledEnd,
              isAllDay: isAllDay,
              serviceMode: serviceMode,
              city: city,
              state: state,
              address: address,
              latitude: latitude,
              longitude: longitude,
              imageBytes: imageBytes,
              imageFilename: imageFilename,
              imageContentType: imageContentType,
            );
      isSubmitting = false;
      notifyListeners();
      return service;
    } on ApiException catch (e) {
      errorMessage = e.message;
      isSubmitting = false;
      notifyListeners();
      return null;
    } catch (_) {
      errorMessage = 'Não foi possível criar o serviço.';
      isSubmitting = false;
      notifyListeners();
      return null;
    }
  }
}
