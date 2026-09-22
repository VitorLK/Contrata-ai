import 'professional_profile_model.dart'
    show PricingType, PricingTypeX, ServiceMode, ServiceModeX;

enum ServiceStatus { aberto, agendado, emAndamento, concluido, cancelado }

extension ServiceStatusX on ServiceStatus {
  String get apiValue {
    switch (this) {
      case ServiceStatus.aberto:
        return 'aberto';
      case ServiceStatus.agendado:
        return 'agendado';
      case ServiceStatus.emAndamento:
        return 'em_andamento';
      case ServiceStatus.concluido:
        return 'concluido';
      case ServiceStatus.cancelado:
        return 'cancelado';
    }
  }

  String get label {
    switch (this) {
      case ServiceStatus.aberto:
        return 'Aberto';
      case ServiceStatus.agendado:
        return 'Agendado';
      case ServiceStatus.emAndamento:
        return 'Em andamento';
      case ServiceStatus.concluido:
        return 'Concluído';
      case ServiceStatus.cancelado:
        return 'Cancelado';
    }
  }

  static ServiceStatus fromApi(String value) {
    switch (value) {
      case 'agendado':
        return ServiceStatus.agendado;
      case 'em_andamento':
        return ServiceStatus.emAndamento;
      case 'concluido':
        return ServiceStatus.concluido;
      case 'cancelado':
        return ServiceStatus.cancelado;
      case 'aberto':
      default:
        return ServiceStatus.aberto;
    }
  }
}

class ServiceModel {
  final String id;
  final String clientId;
  final String? clientName;
  final String title;
  final String description;
  final String? category;
  final double? budget;
  final ServiceStatus status;
  final DateTime createdAt;
  final DateTime scheduledDate;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final bool isAllDay;
  final PricingType? agreedPricingType;
  final double? agreedAmount;
  final String? city;
  final String? state;
  final ServiceMode? serviceMode;
  final DateTime? openConfirmedAt;
  final bool needsOpenConfirmation;
  final int applicationCount;
  // Preenchido só depois que o cliente aceita uma candidatura (Etapa 8).
  // Até lá, sempre chega null da API.
  final String? acceptedProfessionalId;
  final String? imageUrl;
  final String? address;
  final double? latitude;
  final double? longitude;

  const ServiceModel({
    required this.id,
    required this.clientId,
    this.clientName,
    required this.title,
    required this.description,
    this.category,
    this.budget,
    required this.status,
    required this.createdAt,
    required this.scheduledDate,
    this.scheduledStart,
    this.scheduledEnd,
    this.isAllDay = true,
    this.agreedPricingType,
    this.agreedAmount,
    this.city,
    this.state,
    this.serviceMode,
    this.openConfirmedAt,
    this.needsOpenConfirmation = false,
    this.applicationCount = 0,
    this.acceptedProfessionalId,
    this.imageUrl,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      clientName: json['client_name'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String?,
      budget: json['budget'] != null
          ? double.tryParse(json['budget'].toString())
          : null,
      status: ServiceStatusX.fromApi(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      scheduledDate: DateTime.parse(
        (json['scheduled_date'] ?? json['created_at']).toString(),
      ),
      scheduledStart: json['scheduled_start'] == null
          ? null
          : DateTime.parse(json['scheduled_start'].toString()).toLocal(),
      scheduledEnd: json['scheduled_end'] == null
          ? null
          : DateTime.parse(json['scheduled_end'].toString()).toLocal(),
      isAllDay: json['is_all_day'] as bool? ?? true,
      agreedPricingType: json['agreed_pricing_type'] == null
          ? null
          : PricingTypeX.fromApi(json['agreed_pricing_type'].toString()),
      agreedAmount: json['agreed_amount'] == null
          ? null
          : double.tryParse(json['agreed_amount'].toString()),
      city: json['city'] as String?,
      state: json['state'] as String?,
      serviceMode: ServiceModeX.fromApi(json['service_mode'] as String?),
      openConfirmedAt: json['open_confirmed_at'] == null
          ? null
          : DateTime.parse(json['open_confirmed_at'].toString()),
      needsOpenConfirmation: json['needs_open_confirmation'] as bool? ?? false,
      applicationCount:
          int.tryParse(json['application_count']?.toString() ?? '') ?? 0,
      acceptedProfessionalId: json['accepted_professional_id'] as String?,
      imageUrl: json['image_url'] as String?,
      address: json['address'] as String?,
      latitude: json['latitude'] == null
          ? null
          : double.tryParse(json['latitude'].toString()),
      longitude: json['longitude'] == null
          ? null
          : double.tryParse(json['longitude'].toString()),
    );
  }

  String get locationLabel {
    if (serviceMode == ServiceMode.remoto) return 'Remoto';
    if (city != null && state != null) return '$city · $state';
    return serviceMode?.label ?? 'Local a combinar';
  }

  String get fullLocationLabel {
    if (serviceMode == ServiceMode.remoto) return 'Atendimento remoto';
    if (address != null && address!.trim().isNotEmpty) {
      return '$address · $locationLabel';
    }
    return locationLabel;
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  bool overlapsDay(DateTime day) {
    final start = scheduledStart ?? scheduledDate;
    final end = scheduledEnd ?? scheduledDate.add(const Duration(days: 1));
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return start.isBefore(dayEnd) && end.isAfter(dayStart);
  }
}
