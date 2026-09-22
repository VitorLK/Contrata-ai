import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/work_session_model.dart';
import '../services/work_repository.dart';
import 'services_list_viewmodel.dart' show LoadStatus;

class ClientWorkCenterViewModel extends ChangeNotifier {
  final WorkRepository workRepository;

  ClientWorkCenterViewModel({required this.workRepository});

  LoadStatus status = LoadStatus.idle;
  List<WorkSessionModel> pending = [];
  List<AppNotificationModel> notifications = [];
  ClientWorkPreferencesModel preferences = const ClientWorkPreferencesModel();
  String? errorMessage;
  bool isSavingPreference = false;
  String? confirmingSessionId;

  int get unreadCount =>
      notifications.where((item) => item.readAt == null).length;

  List<AppNotificationModel> get historyNotifications {
    final seenEvents = <String>{};
    return notifications.where((notification) {
      if (notification.actionRequired) return false;
      final reference = notification.workSessionId ?? notification.serviceId;
      final key = reference == null
          ? notification.id
          : '${notification.type}:$reference';
      return seenEvents.add(key);
    }).toList();
  }

  Future<void> load() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        workRepository.listPendingConfirmations(),
        workRepository.listNotifications(),
        workRepository.getPreferences(),
      ]);
      pending = results[0] as List<WorkSessionModel>;
      notifications = results[1] as List<AppNotificationModel>;
      preferences = results[2] as ClientWorkPreferencesModel;
      if (notifications.any((item) => item.readAt == null)) {
        try {
          await workRepository.markAllNotificationsRead();
          final viewedAt = DateTime.now();
          notifications = notifications
              .map(
                (item) => item.readAt == null
                    ? item.copyWith(readAt: viewedAt)
                    : item,
              )
              .toList();
        } catch (_) {
          // A central continua utilizável mesmo se a atualização de leitura falhar.
        }
      }
      status = LoadStatus.loaded;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = LoadStatus.error;
    } catch (_) {
      errorMessage = 'Não foi possível carregar sua central de trabalho.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> setRequireConfirmation(bool value) async {
    final previous = preferences;
    preferences = ClientWorkPreferencesModel(requireConfirmation: value);
    isSavingPreference = true;
    notifyListeners();
    try {
      preferences = await workRepository.updatePreferences(value);
    } catch (_) {
      preferences = previous;
      rethrow;
    } finally {
      isSavingPreference = false;
      notifyListeners();
    }
  }

  Future<WorkSessionModel> confirm(String sessionId) async {
    confirmingSessionId = sessionId;
    notifyListeners();
    try {
      final confirmed = await workRepository.confirmWork(sessionId);
      await load();
      return confirmed;
    } finally {
      confirmingSessionId = null;
      notifyListeners();
    }
  }

  Future<void> markRead(AppNotificationModel notification) async {
    if (notification.readAt != null) return;
    final previous = notifications;
    notifications = notifications
        .map(
          (item) => item.id == notification.id
              ? item.copyWith(readAt: DateTime.now())
              : item,
        )
        .toList();
    notifyListeners();
    try {
      await workRepository.markNotificationRead(notification.id);
    } catch (_) {
      notifications = previous;
      notifyListeners();
      rethrow;
    }
  }
}
