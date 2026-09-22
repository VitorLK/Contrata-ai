import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../models/work_session_model.dart';
import 'professional_repository.dart' show inferImageContentType;

class WorkRepository {
  final ApiClient apiClient;

  WorkRepository({required this.apiClient});

  Future<List<WorkAssignmentModel>> listTodayWork() async {
    final data = await apiClient.get('/work/today', auth: true);
    return (data as List)
        .map(
          (item) => WorkAssignmentModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<WorkAssignmentModel>> listAgenda({
    required DateTime from,
    required DateTime to,
  }) async {
    final query = Uri(
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    ).query;
    final data = await apiClient.get('/work/agenda?$query', auth: true);
    return (data as List)
        .map(
          (item) => WorkAssignmentModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<WorkSessionModel> startWork(String serviceId) async {
    final data = await apiClient.post(
      '/work/services/$serviceId/start',
      {},
      auth: true,
    );
    return WorkSessionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> withdrawScheduledWork({
    required String serviceId,
    required String reason,
  }) async {
    await apiClient.post('/work/services/$serviceId/withdraw', {
      'reason': reason,
    }, auth: true);
  }

  Future<WorkSessionModel> finishWork({
    required String sessionId,
    String? note,
    Uint8List? evidenceBytes,
    String? evidenceFilename,
    String? evidenceContentType,
  }) async {
    dynamic data;
    if (evidenceBytes == null || evidenceFilename == null) {
      data = await apiClient.post('/work/$sessionId/finish', {
        if (note != null && note.isNotEmpty) 'note': note,
      }, auth: true);
    } else {
      data = await apiClient.postMultipart(
        '/work/$sessionId/finish',
        fieldName: 'evidence',
        bytes: evidenceBytes,
        filename: evidenceFilename,
        contentType:
            evidenceContentType ?? inferImageContentType(evidenceFilename),
        fields: {if (note != null && note.isNotEmpty) 'note': note},
        auth: true,
      );
    }
    return WorkSessionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<WorkSessionModel>> listPendingConfirmations() async {
    final data = await apiClient.get('/work/pending-confirmations', auth: true);
    return (data as List)
        .map((item) => WorkSessionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WorkSessionModel> confirmWork(String sessionId) async {
    final data = await apiClient.post(
      '/work/$sessionId/confirm',
      {},
      auth: true,
    );
    return WorkSessionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ClientWorkPreferencesModel> getPreferences() async {
    final data = await apiClient.get('/work/preferences', auth: true);
    return ClientWorkPreferencesModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ClientWorkPreferencesModel> updatePreferences(
    bool requireConfirmation,
  ) async {
    final data = await apiClient.put('/work/preferences', {
      'require_work_confirmation': requireConfirmation,
    }, auth: true);
    return ClientWorkPreferencesModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<AppNotificationModel>> listNotifications() async {
    final data = await apiClient.get('/work/notifications', auth: true);
    return (data as List)
        .map(
          (item) => AppNotificationModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await apiClient.post(
      '/work/notifications/$notificationId/read',
      {},
      auth: true,
    );
  }

  Future<void> markAllNotificationsRead() async {
    await apiClient.post('/work/notifications/read-all', {}, auth: true);
  }

  Future<PerformanceModel> getPerformance(String month) async {
    final data = await apiClient.get(
      '/work/performance?month=${Uri.encodeQueryComponent(month)}',
      auth: true,
    );
    return PerformanceModel.fromJson(data as Map<String, dynamic>);
  }

  Future<WorkReceiptModel> getReceipt(String sessionId) async {
    final data = await apiClient.get('/work/$sessionId/receipt', auth: true);
    return WorkReceiptModel.fromJson(data as Map<String, dynamic>);
  }
}
