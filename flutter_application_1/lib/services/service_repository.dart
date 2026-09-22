import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../models/application_model.dart';
import '../models/service_model.dart';
import '../models/professional_profile_model.dart';

/// Fala com os endpoints /services/* do back-end.
class ServiceRepository {
  final ApiClient apiClient;

  ServiceRepository({required this.apiClient});

  Future<List<ServiceModel>> listServices({
    String? queryText,
    String? category,
    String? status,
    String? dateScope,
    String? state,
    String? city,
    ServiceMode? serviceMode,
    double? minBudget,
    double? maxBudget,
  }) async {
    final query = <String, String>{
      if (queryText != null && queryText.isNotEmpty) 'q': queryText,
      if (category != null && category.isNotEmpty) 'category': category,
      if (status != null && status.isNotEmpty) 'status': status,
      if (dateScope != null && dateScope.isNotEmpty) 'date_scope': dateScope,
      if (state != null && state.isNotEmpty) 'state': state,
      if (city != null && city.isNotEmpty) 'city': city,
      if (serviceMode != null) 'service_mode': serviceMode.apiValue,
      if (minBudget != null) 'min_budget': minBudget.toStringAsFixed(2),
      if (maxBudget != null) 'max_budget': maxBudget.toStringAsFixed(2),
    };
    final path = query.isEmpty
        ? '/services'
        : '/services?${Uri(queryParameters: query).query}';
    final data = await apiClient.get(path);
    return (data as List)
        .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ServiceModel>> listMyServices() async {
    final data = await apiClient.get('/services/mine', auth: true);
    return (data as List)
        .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ServiceModel> getById(String id) async {
    final data = await apiClient.get('/services/$id');
    return ServiceModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ServiceModel> createService({
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
    Uint8List? imageBytes,
    String? imageFilename,
    String? imageContentType,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      if (category != null && category.isNotEmpty) 'category': category,
      'budget': budget,
      'scheduled_date': _apiDate(scheduledDate),
      'scheduled_start': scheduledStart.toUtc().toIso8601String(),
      'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
      'is_all_day': isAllDay,
      'service_mode': serviceMode.apiValue,
      'city': ?city,
      'state': ?state,
      'address': ?address,
      'latitude': latitude,
      'longitude': longitude,
    };
    final data = imageBytes == null
        ? await apiClient.post('/services', body, auth: true)
        : await apiClient.postMultipart(
            '/services',
            fieldName: 'image',
            bytes: imageBytes,
            filename: imageFilename ?? 'servico.jpg',
            contentType: imageContentType ?? 'image/jpeg',
            fields: _multipartFields(body),
            auth: true,
          );
    return ServiceModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ServiceModel> updateService({
    required String serviceId,
    required String title,
    required String description,
    required String category,
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
    Uint8List? imageBytes,
    String? imageFilename,
    String? imageContentType,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'category': category,
      'budget': budget,
      'scheduled_date': _apiDate(scheduledDate),
      'scheduled_start': scheduledStart.toUtc().toIso8601String(),
      'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
      'is_all_day': isAllDay,
      'service_mode': serviceMode.apiValue,
      'city': ?city,
      'state': ?state,
      'address': ?address,
      'latitude': latitude,
      'longitude': longitude,
    };
    final data = imageBytes == null
        ? await apiClient.put('/services/$serviceId', body, auth: true)
        : await apiClient.putMultipart(
            '/services/$serviceId',
            fieldName: 'image',
            bytes: imageBytes,
            filename: imageFilename ?? 'servico.jpg',
            contentType: imageContentType ?? 'image/jpeg',
            fields: _multipartFields(body),
            auth: true,
          );
    return ServiceModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> renewService(String serviceId) async {
    await apiClient.post('/services/$serviceId/renew', {}, auth: true);
  }

  Future<void> applyToService({
    required String serviceId,
    String? message,
  }) async {
    await apiClient.post('/services/$serviceId/apply', {
      if (message != null && message.isNotEmpty) 'message': message,
    }, auth: true);
  }

  Future<List<ApplicationModel>> listApplications(String serviceId) async {
    final data = await apiClient.get(
      '/services/$serviceId/applications',
      auth: true,
    );
    return (data as List)
        .map((e) => ApplicationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptApplication({
    required String serviceId,
    required String applicationId,
  }) async {
    await apiClient.post(
      '/services/$serviceId/applications/$applicationId/accept',
      {},
      auth: true,
    );
  }

  Future<void> rejectApplication({
    required String serviceId,
    required String applicationId,
  }) async {
    await apiClient.post(
      '/services/$serviceId/applications/$applicationId/reject',
      {},
      auth: true,
    );
  }

  Future<void> completeService(String serviceId) async {
    await apiClient.post('/services/$serviceId/complete', {}, auth: true);
  }

  Future<void> cancelService(String serviceId) async {
    await apiClient.post('/services/$serviceId/cancel', {}, auth: true);
  }

  Future<void> submitReview({
    required String serviceId,
    required int rating,
    String? comment,
  }) async {
    await apiClient.post('/services/$serviceId/review', {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    }, auth: true);
  }
}

String _apiDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Map<String, String> _multipartFields(Map<String, dynamic> body) {
  return body.map(
    (key, value) => MapEntry(key, value == null ? '' : value.toString()),
  );
}
