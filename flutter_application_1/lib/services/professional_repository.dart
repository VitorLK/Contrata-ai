import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../models/professional_profile_model.dart';
import '../models/availability_model.dart';

/// Deduz o Content-Type a partir da extensão do arquivo — usado quando
/// XFile.mimeType não vem preenchido (comum fora da web). O back-end
/// rejeita upload sem um Content-Type de imagem reconhecido (ver
/// middlewares/upload.js).
String inferImageContentType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Fala com os endpoints /professionals/* do back-end.
class ProfessionalRepository {
  final ApiClient apiClient;

  ProfessionalRepository({required this.apiClient});

  Future<ProfessionalProfileModel> getMyProfile() async {
    final data = await apiClient.get('/professionals/me', auth: true);
    return ProfessionalProfileModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ProfessionalProfileModel> updateMyProfile({
    String? bio,
    List<String>? skills,
    double? hourlyRate,
    PricingType? pricingType,
    double? projectRate,
    String? experience,
    String? city,
    String? state,
    ServiceMode? serviceMode,
    String? availability,
    String? phone,
  }) async {
    final data = await apiClient.put('/professionals/me', {
      'bio': ?bio,
      'skills': ?skills,
      'hourly_rate': ?hourlyRate,
      'pricing_type': ?pricingType?.apiValue,
      'project_rate': ?projectRate,
      'experience': ?experience,
      'city': ?city,
      'state': ?state,
      'service_mode': ?serviceMode?.apiValue,
      'availability': ?availability,
      'phone': ?phone,
    }, auth: true);
    return ProfessionalProfileModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ProfessionalAvailabilityModel> getMyAvailability() async {
    final data = await apiClient.get(
      '/professionals/me/availability',
      auth: true,
    );
    return ProfessionalAvailabilityModel.fromJson(
      data as Map<String, dynamic>,
    );
  }

  Future<ProfessionalAvailabilityModel> updateMyAvailability(
    ProfessionalAvailabilityModel availability,
  ) async {
    final data = await apiClient.put(
      '/professionals/me/availability',
      availability.toJson(),
      auth: true,
    );
    return ProfessionalAvailabilityModel.fromJson(
      data as Map<String, dynamic>,
    );
  }

  Future<ProfessionalAvailabilityModel> getPublicAvailability(
    String professionalId,
  ) async {
    final data = await apiClient.get(
      '/professionals/$professionalId/availability',
    );
    return ProfessionalAvailabilityModel.fromJson(
      data as Map<String, dynamic>,
    );
  }

  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final data = await apiClient.postMultipart(
      '/professionals/me/photo',
      fieldName: 'photo',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      auth: true,
    );
    return (data as Map<String, dynamic>)['photo_url'] as String;
  }

  Future<PortfolioItemModel> addPortfolioItem({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final data = await apiClient.postMultipart(
      '/professionals/me/portfolio',
      fieldName: 'image',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      auth: true,
    );
    return PortfolioItemModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deletePortfolioItem(String itemId) async {
    await apiClient.delete('/professionals/me/portfolio/$itemId', auth: true);
  }

  Future<List<ProfessionalSummaryModel>> listProfessionals({
    String? queryText,
    String? category,
    String? state,
    String? city,
    List<ServiceMode> serviceModes = const [],
    PricingType? pricingType,
    double? maxHourlyRate,
    String? availability,
    String? sort,
  }) async {
    final query = <String, String>{
      if (queryText != null && queryText.isNotEmpty) 'q': queryText,
      if (category != null && category.isNotEmpty) 'category': category,
      if (state != null && state.isNotEmpty) 'state': state,
      if (city != null && city.isNotEmpty) 'city': city,
      if (serviceModes.isNotEmpty)
        'service_mode': serviceModes.map((mode) => mode.apiValue).join(','),
      if (pricingType != null) 'pricing_type': pricingType.apiValue,
      if (maxHourlyRate != null) 'max_price': maxHourlyRate.toStringAsFixed(2),
      if (availability != null && availability.isNotEmpty)
        'availability': availability,
      if (sort != null && sort.isNotEmpty) 'sort': sort,
    };
    final path = query.isEmpty
        ? '/professionals'
        : '/professionals?${Uri(queryParameters: query).query}';
    final data = await apiClient.get(path);
    return (data as List)
        .map(
          (e) => ProfessionalSummaryModel.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<PublicProfessionalProfileModel> getPublicProfile(
    String professionalId,
  ) async {
    final data = await apiClient.get('/professionals/$professionalId');
    return PublicProfessionalProfileModel.fromJson(
      data as Map<String, dynamic>,
    );
  }
}
