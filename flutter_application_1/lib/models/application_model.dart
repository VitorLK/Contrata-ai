import 'professional_profile_model.dart'
    show PricingType, PricingTypeX, ServiceMode, ServiceModeX;
import 'service_model.dart' show ServiceStatus, ServiceStatusX;

enum ApplicationStatus { pendente, aceito, recusado }

extension ApplicationStatusX on ApplicationStatus {
  String get apiValue {
    switch (this) {
      case ApplicationStatus.pendente:
        return 'pendente';
      case ApplicationStatus.aceito:
        return 'aceito';
      case ApplicationStatus.recusado:
        return 'recusado';
    }
  }

  String get label {
    switch (this) {
      case ApplicationStatus.pendente:
        return 'Pendente';
      case ApplicationStatus.aceito:
        return 'Aceito';
      case ApplicationStatus.recusado:
        return 'Recusado';
    }
  }

  static ApplicationStatus fromApi(String value) {
    switch (value) {
      case 'aceito':
        return ApplicationStatus.aceito;
      case 'recusado':
        return ApplicationStatus.recusado;
      case 'pendente':
      default:
        return ApplicationStatus.pendente;
    }
  }
}

class ApplicationModel {
  final String id;
  final String serviceId;
  final String professionalId;
  final String? professionalName;
  final String? professionalPhotoUrl;
  final List<String> professionalSkills;
  final PricingType pricingType;
  final double? hourlyRate;
  final double? projectRate;
  final double? ratingAverage;
  final int ratingCount;
  final String? message;
  final ApplicationStatus status;
  final DateTime createdAt;
  // Só vêm preenchidos em GET /applications/mine (visão do profissional) —
  // GET /services/:id/applications (visão do cliente) já sabe de qual
  // serviço se trata, então o back-end não repete essa informação.
  final String? serviceTitle;
  final ServiceStatus? serviceStatus;
  final String? clientName;
  final String? serviceCategory;
  final double? serviceBudget;
  final DateTime? serviceScheduledDate;
  final String? serviceCity;
  final String? serviceState;
  final ServiceMode? serviceMode;

  const ApplicationModel({
    required this.id,
    required this.serviceId,
    required this.professionalId,
    this.professionalName,
    this.professionalPhotoUrl,
    this.professionalSkills = const [],
    this.pricingType = PricingType.porHora,
    this.hourlyRate,
    this.projectRate,
    this.ratingAverage,
    this.ratingCount = 0,
    this.message,
    required this.status,
    required this.createdAt,
    this.serviceTitle,
    this.serviceStatus,
    this.clientName,
    this.serviceCategory,
    this.serviceBudget,
    this.serviceScheduledDate,
    this.serviceCity,
    this.serviceState,
    this.serviceMode,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    return ApplicationModel(
      id: json['id'] as String,
      serviceId: json['service_id'] as String,
      professionalId: json['professional_id'] as String,
      professionalName: json['professional_name'] as String?,
      professionalPhotoUrl: json['photo_url'] as String?,
      professionalSkills: (json['professional_skills'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      pricingType: PricingTypeX.fromApi(json['pricing_type'] as String?),
      hourlyRate: json['hourly_rate'] == null
          ? null
          : double.tryParse(json['hourly_rate'].toString()),
      projectRate: json['project_rate'] == null
          ? null
          : double.tryParse(json['project_rate'].toString()),
      ratingAverage: json['rating_average'] == null
          ? null
          : double.tryParse(json['rating_average'].toString()),
      ratingCount: int.tryParse(json['rating_count']?.toString() ?? '') ?? 0,
      message: json['message'] as String?,
      status: ApplicationStatusX.fromApi(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      serviceTitle: json['service_title'] as String?,
      serviceStatus: json['service_status'] != null
          ? ServiceStatusX.fromApi(json['service_status'] as String)
          : null,
      clientName: json['client_name'] as String?,
      serviceCategory: json['service_category'] as String?,
      serviceBudget: json['service_budget'] == null
          ? null
          : double.tryParse(json['service_budget'].toString()),
      serviceScheduledDate: json['service_scheduled_date'] == null
          ? null
          : DateTime.parse(json['service_scheduled_date'].toString()),
      serviceCity: json['service_city'] as String?,
      serviceState: json['service_state'] as String?,
      serviceMode: ServiceModeX.fromApi(json['service_mode'] as String?),
    );
  }

  String get serviceLocationLabel {
    if (serviceMode == ServiceMode.remoto) return 'Remoto';
    if (serviceCity != null && serviceState != null) {
      return '$serviceCity · $serviceState';
    }
    return 'Local a combinar';
  }
}
