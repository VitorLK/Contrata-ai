import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/work_session_model.dart';
import '../services/work_repository.dart';
import 'services_list_viewmodel.dart' show LoadStatus;

class WorkdayViewModel extends ChangeNotifier {
  final WorkRepository workRepository;

  WorkdayViewModel({required this.workRepository});

  LoadStatus status = LoadStatus.idle;
  List<WorkAssignmentModel> assignments = [];
  String? errorMessage;
  bool isMutating = false;
  DateTime selectedDay = _dateOnly(DateTime.now());
  DateTime weekStart = _mondayOf(DateTime.now());

  WorkAssignmentModel? get activeAssignment {
    for (final assignment in assignments) {
      if (assignment.session?.status == WorkSessionStatus.emAndamento) {
        return assignment;
      }
    }
    return null;
  }

  List<WorkAssignmentModel> get selectedDayAssignments => assignments
      .where((assignment) => assignment.service.overlapsDay(selectedDay))
      .toList();

  int countForDay(DateTime day) => assignments
      .where((assignment) => assignment.service.overlapsDay(day))
      .length;

  bool get selectedDayIsToday => _sameDay(selectedDay, DateTime.now());

  bool canStart(WorkAssignmentModel assignment, DateTime now) {
    if (activeAssignment != null) return false;
    final start = assignment.service.scheduledStart;
    if (start == null) return _sameDay(assignment.service.scheduledDate, now);
    return !now.isBefore(start.subtract(const Duration(minutes: 30)));
  }

  Future<void> load() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final from = weekStart;
      final to = weekStart.add(const Duration(days: 7));
      assignments = await workRepository.listAgenda(from: from, to: to);
      status = LoadStatus.loaded;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = LoadStatus.error;
    } catch (_) {
      errorMessage = 'Não foi possível carregar seu trabalho do dia.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> selectDay(DateTime day) async {
    final normalized = _dateOnly(day);
    final targetWeek = _mondayOf(normalized);
    selectedDay = normalized;
    if (!_sameDay(targetWeek, weekStart)) {
      weekStart = targetWeek;
      await load();
    } else {
      notifyListeners();
    }
  }

  Future<void> previousWeek() async {
    weekStart = weekStart.subtract(const Duration(days: 7));
    selectedDay = weekStart;
    await load();
  }

  Future<void> nextWeek() async {
    weekStart = weekStart.add(const Duration(days: 7));
    selectedDay = weekStart;
    await load();
  }

  Future<void> goToToday() async {
    selectedDay = _dateOnly(DateTime.now());
    weekStart = _mondayOf(selectedDay);
    await load();
  }

  Future<void> start(String serviceId) async {
    isMutating = true;
    notifyListeners();
    try {
      await workRepository.startWork(serviceId);
      await load();
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<void> withdraw({
    required String serviceId,
    required String reason,
  }) async {
    isMutating = true;
    notifyListeners();
    try {
      await workRepository.withdrawScheduledWork(
        serviceId: serviceId,
        reason: reason,
      );
      await load();
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<WorkSessionModel> finish({
    required String sessionId,
    String? note,
    Uint8List? evidenceBytes,
    String? evidenceFilename,
    String? evidenceContentType,
  }) async {
    isMutating = true;
    notifyListeners();
    try {
      final result = await workRepository.finishWork(
        sessionId: sessionId,
        note: note,
        evidenceBytes: evidenceBytes,
        evidenceFilename: evidenceFilename,
        evidenceContentType: evidenceContentType,
      );
      await load();
      return result;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _mondayOf(DateTime date) {
  final normalized = _dateOnly(date);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
