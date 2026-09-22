import 'service_model.dart';

enum WorkSessionStatus {
  emAndamento,
  aguardandoConfirmacao,
  confirmado,
  contestado,
}

extension WorkSessionStatusX on WorkSessionStatus {
  String get label {
    switch (this) {
      case WorkSessionStatus.emAndamento:
        return 'Em andamento';
      case WorkSessionStatus.aguardandoConfirmacao:
        return 'Aguardando confirmação';
      case WorkSessionStatus.confirmado:
        return 'Confirmado';
      case WorkSessionStatus.contestado:
        return 'Contestado';
    }
  }

  static WorkSessionStatus fromApi(String? value) {
    switch (value) {
      case 'aguardando_confirmacao':
        return WorkSessionStatus.aguardandoConfirmacao;
      case 'confirmado':
        return WorkSessionStatus.confirmado;
      case 'contestado':
        return WorkSessionStatus.contestado;
      default:
        return WorkSessionStatus.emAndamento;
    }
  }
}

class WorkSessionModel {
  final String id;
  final String serviceId;
  final String professionalId;
  final String clientId;
  final String? serviceTitle;
  final String? category;
  final String? clientName;
  final String? professionalName;
  final DateTime? scheduledDate;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final bool isAllDay;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  final double? hourlyRateSnapshot;
  final double? fixedAmountSnapshot;
  final String amountBasis;
  final double? amount;
  final String? providerNote;
  final String? evidencePhotoUrl;
  final WorkSessionStatus status;
  final DateTime? confirmedAt;

  const WorkSessionModel({
    required this.id,
    required this.serviceId,
    required this.professionalId,
    required this.clientId,
    this.serviceTitle,
    this.category,
    this.clientName,
    this.professionalName,
    this.scheduledDate,
    this.scheduledStart,
    this.scheduledEnd,
    this.isAllDay = true,
    required this.startedAt,
    this.endedAt,
    this.durationMinutes,
    this.hourlyRateSnapshot,
    this.fixedAmountSnapshot,
    required this.amountBasis,
    this.amount,
    this.providerNote,
    this.evidencePhotoUrl,
    required this.status,
    this.confirmedAt,
  });

  factory WorkSessionModel.fromJson(Map<String, dynamic> json) {
    double? number(String key) =>
        json[key] == null ? null : double.tryParse(json[key].toString());

    return WorkSessionModel(
      id: json['id'].toString(),
      serviceId: json['service_id'].toString(),
      professionalId: json['professional_id'].toString(),
      clientId: json['client_id'].toString(),
      serviceTitle: json['service_title'] as String?,
      category: json['category'] as String?,
      clientName: json['client_name'] as String?,
      professionalName: json['professional_name'] as String?,
      scheduledDate: json['scheduled_date'] == null
          ? null
          : DateTime.parse(json['scheduled_date'].toString()),
      scheduledStart: json['scheduled_start'] == null
          ? null
          : DateTime.parse(json['scheduled_start'].toString()).toLocal(),
      scheduledEnd: json['scheduled_end'] == null
          ? null
          : DateTime.parse(json['scheduled_end'].toString()).toLocal(),
      isAllDay: json['is_all_day'] as bool? ?? true,
      startedAt: DateTime.parse(json['started_at'].toString()),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'].toString()),
      durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? ''),
      hourlyRateSnapshot: number('hourly_rate_snapshot'),
      fixedAmountSnapshot: number('fixed_amount_snapshot'),
      amountBasis: json['amount_basis']?.toString() ?? 'valor_fixo',
      amount: number('amount'),
      providerNote: json['provider_note'] as String?,
      evidencePhotoUrl: json['evidence_photo_url'] as String?,
      status: WorkSessionStatusX.fromApi(json['status'] as String?),
      confirmedAt: json['confirmed_at'] == null
          ? null
          : DateTime.parse(json['confirmed_at'].toString()),
    );
  }
}

class WorkAssignmentModel {
  final ServiceModel service;
  final WorkSessionModel? session;

  const WorkAssignmentModel({required this.service, this.session});

  factory WorkAssignmentModel.fromJson(Map<String, dynamic> json) {
    return WorkAssignmentModel(
      service: ServiceModel.fromJson(json['service'] as Map<String, dynamic>),
      session: json['session'] == null
          ? null
          : WorkSessionModel.fromJson(json['session'] as Map<String, dynamic>),
    );
  }
}

class PerformanceSummaryModel {
  final int serviceCount;
  final int totalMinutes;
  final double totalAmount;

  const PerformanceSummaryModel({
    this.serviceCount = 0,
    this.totalMinutes = 0,
    this.totalAmount = 0,
  });

  factory PerformanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return PerformanceSummaryModel(
      serviceCount: int.tryParse(json['service_count']?.toString() ?? '') ?? 0,
      totalMinutes: int.tryParse(json['total_minutes']?.toString() ?? '') ?? 0,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '') ?? 0,
    );
  }
}

class DailyPerformanceModel extends PerformanceSummaryModel {
  final DateTime day;

  const DailyPerformanceModel({
    required this.day,
    super.serviceCount,
    super.totalMinutes,
    super.totalAmount,
  });

  factory DailyPerformanceModel.fromJson(Map<String, dynamic> json) {
    final summary = PerformanceSummaryModel.fromJson(json);
    return DailyPerformanceModel(
      day: DateTime.parse(json['day'].toString()),
      serviceCount: summary.serviceCount,
      totalMinutes: summary.totalMinutes,
      totalAmount: summary.totalAmount,
    );
  }
}

class PerformanceModel {
  final String month;
  final PerformanceSummaryModel week;
  final PerformanceSummaryModel monthSummary;
  final List<DailyPerformanceModel> daily;
  final List<WorkSessionModel> history;

  const PerformanceModel({
    required this.month,
    required this.week,
    required this.monthSummary,
    this.daily = const [],
    this.history = const [],
  });

  factory PerformanceModel.fromJson(Map<String, dynamic> json) {
    return PerformanceModel(
      month: json['month'].toString(),
      week: PerformanceSummaryModel.fromJson(
        json['week'] as Map<String, dynamic>,
      ),
      monthSummary: PerformanceSummaryModel.fromJson(
        json['month_summary'] as Map<String, dynamic>,
      ),
      daily: (json['daily'] as List? ?? const [])
          .map(
            (item) =>
                DailyPerformanceModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      history: (json['history'] as List? ?? const [])
          .map(
            (item) => WorkSessionModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class WorkReceiptModel {
  final String receiptNumber;
  final String documentType;
  final WorkSessionModel session;

  const WorkReceiptModel({
    required this.receiptNumber,
    required this.documentType,
    required this.session,
  });

  factory WorkReceiptModel.fromJson(Map<String, dynamic> json) {
    return WorkReceiptModel(
      receiptNumber: json['receipt_number'].toString(),
      documentType: json['document_type'].toString(),
      session: WorkSessionModel.fromJson(json),
    );
  }
}

class ClientWorkPreferencesModel {
  final bool requireConfirmation;

  const ClientWorkPreferencesModel({this.requireConfirmation = true});

  factory ClientWorkPreferencesModel.fromJson(Map<String, dynamic> json) {
    return ClientWorkPreferencesModel(
      requireConfirmation: json['require_work_confirmation'] as bool? ?? true,
    );
  }
}

class AppNotificationModel {
  final String id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool actionRequired;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data = const {},
    this.actionRequired = false,
    required this.createdAt,
    this.readAt,
  });

  String? get serviceId => data['service_id']?.toString();

  String? get workSessionId => data['work_session_id']?.toString();

  bool get isResolvedConfirmation =>
      type == 'confirmacao_pendente' && !actionRequired;

  AppNotificationModel copyWith({DateTime? readAt}) {
    return AppNotificationModel(
      id: id,
      type: type,
      title: title,
      message: message,
      data: data,
      actionRequired: actionRequired,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return AppNotificationModel(
      id: json['id'].toString(),
      type: json['type'].toString(),
      title: json['title'].toString(),
      message: json['message'].toString(),
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
      actionRequired: json['action_required'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'].toString()),
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'].toString()),
    );
  }
}
