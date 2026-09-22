import 'review_model.dart';
import 'availability_model.dart';

enum ServiceMode { presencial, remoto, hibrido }

enum PricingType { porHora, empreitada }

extension PricingTypeX on PricingType {
  String get apiValue => switch (this) {
    PricingType.porHora => 'por_hora',
    PricingType.empreitada => 'empreitada',
  };

  String get label => switch (this) {
    PricingType.porHora => 'Por hora',
    PricingType.empreitada => 'Por empreitada',
  };

  String get description => switch (this) {
    PricingType.porHora => 'O total considera as horas registradas na jornada.',
    PricingType.empreitada =>
      'Um valor fechado é combinado para o trabalho completo.',
  };

  static PricingType fromApi(String? value) => switch (value) {
    'empreitada' => PricingType.empreitada,
    _ => PricingType.porHora,
  };
}

extension ServiceModeX on ServiceMode {
  String get apiValue {
    switch (this) {
      case ServiceMode.presencial:
        return 'presencial';
      case ServiceMode.remoto:
        return 'remoto';
      case ServiceMode.hibrido:
        return 'hibrido';
    }
  }

  String get label {
    switch (this) {
      case ServiceMode.presencial:
        return 'Presencial';
      case ServiceMode.remoto:
        return 'Remoto';
      case ServiceMode.hibrido:
        return 'Híbrido';
    }
  }

  static ServiceMode? fromApi(String? value) {
    switch (value) {
      case 'presencial':
        return ServiceMode.presencial;
      case 'remoto':
        return ServiceMode.remoto;
      case 'hibrido':
        return ServiceMode.hibrido;
      default:
        return null;
    }
  }
}

class PortfolioItemModel {
  final String id;
  final String professionalId;
  final String imageUrl;
  final DateTime createdAt;

  const PortfolioItemModel({
    required this.id,
    required this.professionalId,
    required this.imageUrl,
    required this.createdAt,
  });

  factory PortfolioItemModel.fromJson(Map<String, dynamic> json) {
    return PortfolioItemModel(
      id: json['id'] as String,
      professionalId: json['professional_id'] as String,
      imageUrl: json['image_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Perfil completo do profissional — dados básicos de usuário (nome,
/// e-mail, telefone) combinados com o perfil estendido
/// (professional_profiles) e o portfólio, do jeito que GET
/// /professionals/me devolve tudo junto.
class ProfessionalProfileModel {
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? bio;
  final List<String> skills;
  final double? hourlyRate;
  final PricingType pricingType;
  final double? projectRate;
  final String? photoUrl;
  final String? experience;
  final String? city;
  final String? state;
  final ServiceMode? serviceMode;
  final String? availability;
  final ProfessionalAvailabilityModel availabilitySchedule;
  final int profileCompletion;
  final List<PortfolioItemModel> portfolio;

  const ProfessionalProfileModel({
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.bio,
    this.skills = const [],
    this.hourlyRate,
    this.pricingType = PricingType.porHora,
    this.projectRate,
    this.photoUrl,
    this.experience,
    this.city,
    this.state,
    this.serviceMode,
    this.availability,
    this.availabilitySchedule = const ProfessionalAvailabilityModel(),
    this.profileCompletion = 0,
    this.portfolio = const [],
  });

  factory ProfessionalProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfessionalProfileModel(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      skills:
          (json['skills'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      hourlyRate: json['hourly_rate'] != null
          ? double.tryParse(json['hourly_rate'].toString())
          : null,
      pricingType: PricingTypeX.fromApi(json['pricing_type'] as String?),
      projectRate: json['project_rate'] != null
          ? double.tryParse(json['project_rate'].toString())
          : null,
      photoUrl: json['photo_url'] as String?,
      experience: json['experience'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      serviceMode: ServiceModeX.fromApi(json['service_mode'] as String?),
      availability: json['availability'] as String?,
      availabilitySchedule: json['availability_schedule'] is Map
          ? ProfessionalAvailabilityModel.fromJson(
              Map<String, dynamic>.from(
                json['availability_schedule'] as Map,
              ),
            )
          : const ProfessionalAvailabilityModel(),
      profileCompletion: json['profile_completion'] as int? ?? 0,
      portfolio: (json['portfolio'] as List? ?? const [])
          .map((e) => PortfolioItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Item da lista pública de profissionais (GET /professionals) — um
/// subconjunto de campos; telefone/experiência/disponibilidade só
/// aparecem no perfil público completo, não na lista.
class ProfessionalSummaryModel {
  final String userId;
  final String name;
  final String? bio;
  final List<String> skills;
  final double? hourlyRate;
  final PricingType pricingType;
  final double? projectRate;
  final String? photoUrl;
  final String? city;
  final String? state;
  final ServiceMode? serviceMode;
  final String? availability;
  final ProfessionalAvailabilityModel availabilitySchedule;
  final double? ratingAverage;
  final int ratingCount;

  const ProfessionalSummaryModel({
    required this.userId,
    required this.name,
    this.bio,
    this.skills = const [],
    this.hourlyRate,
    this.pricingType = PricingType.porHora,
    this.projectRate,
    this.photoUrl,
    this.city,
    this.state,
    this.serviceMode,
    this.availability,
    this.availabilitySchedule = const ProfessionalAvailabilityModel(),
    this.ratingAverage,
    this.ratingCount = 0,
  });

  factory ProfessionalSummaryModel.fromJson(Map<String, dynamic> json) {
    return ProfessionalSummaryModel(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      skills:
          (json['skills'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      hourlyRate: json['hourly_rate'] != null
          ? double.tryParse(json['hourly_rate'].toString())
          : null,
      pricingType: PricingTypeX.fromApi(json['pricing_type'] as String?),
      projectRate: json['project_rate'] != null
          ? double.tryParse(json['project_rate'].toString())
          : null,
      photoUrl: json['photo_url'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      serviceMode: ServiceModeX.fromApi(json['service_mode'] as String?),
      availability: json['availability'] as String?,
      availabilitySchedule: json['availability_schedule'] is Map
          ? ProfessionalAvailabilityModel.fromJson(
              Map<String, dynamic>.from(
                json['availability_schedule'] as Map,
              ),
            )
          : const ProfessionalAvailabilityModel(),
      ratingAverage: json['rating_average'] != null
          ? double.tryParse(json['rating_average'].toString())
          : null,
      ratingCount: int.tryParse(json['rating_count']?.toString() ?? '') ?? 0,
    );
  }
}

/// Resumo de avaliações de um profissional — média, total e distribuição
/// por nota (1-5), calculados no back-end (ver summarizeRatings em
/// professionalController.js).
class RatingSummaryModel {
  final double? average;
  final int total;
  final Map<String, int> distribution;

  const RatingSummaryModel({
    this.average,
    this.total = 0,
    this.distribution = const {},
  });

  factory RatingSummaryModel.fromJson(Map<String, dynamic> json) {
    return RatingSummaryModel(
      average: json['average'] != null
          ? double.tryParse(json['average'].toString())
          : null,
      total: json['total'] as int? ?? 0,
      distribution:
          (json['distribution'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v as int),
          ) ??
          const {},
    );
  }
}

/// Perfil público completo de um profissional (GET /professionals/:id) —
/// o que o contratante vê antes de solicitar um serviço. Sem e-mail
/// (nunca exposto fora do próprio usuário autenticado).
class PublicProfessionalProfileModel {
  final String userId;
  final String name;
  final String? phone;
  final String? bio;
  final List<String> skills;
  final double? hourlyRate;
  final PricingType pricingType;
  final double? projectRate;
  final String? photoUrl;
  final String? experience;
  final String? city;
  final String? state;
  final ServiceMode? serviceMode;
  final String? availability;
  final ProfessionalAvailabilityModel availabilitySchedule;
  final List<PortfolioItemModel> portfolio;
  final RatingSummaryModel rating;
  final List<ReviewModel> reviews;

  const PublicProfessionalProfileModel({
    required this.userId,
    required this.name,
    this.phone,
    this.bio,
    this.skills = const [],
    this.hourlyRate,
    this.pricingType = PricingType.porHora,
    this.projectRate,
    this.photoUrl,
    this.experience,
    this.city,
    this.state,
    this.serviceMode,
    this.availability,
    this.availabilitySchedule = const ProfessionalAvailabilityModel(),
    this.portfolio = const [],
    this.rating = const RatingSummaryModel(),
    this.reviews = const [],
  });

  factory PublicProfessionalProfileModel.fromJson(Map<String, dynamic> json) {
    return PublicProfessionalProfileModel(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      skills:
          (json['skills'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      hourlyRate: json['hourly_rate'] != null
          ? double.tryParse(json['hourly_rate'].toString())
          : null,
      pricingType: PricingTypeX.fromApi(json['pricing_type'] as String?),
      projectRate: json['project_rate'] != null
          ? double.tryParse(json['project_rate'].toString())
          : null,
      photoUrl: json['photo_url'] as String?,
      experience: json['experience'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      serviceMode: ServiceModeX.fromApi(json['service_mode'] as String?),
      availability: json['availability'] as String?,
      availabilitySchedule: json['availability_schedule'] is Map
          ? ProfessionalAvailabilityModel.fromJson(
              Map<String, dynamic>.from(
                json['availability_schedule'] as Map,
              ),
            )
          : const ProfessionalAvailabilityModel(),
      portfolio: (json['portfolio'] as List? ?? const [])
          .map((e) => PortfolioItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      rating: json['rating'] != null
          ? RatingSummaryModel.fromJson(json['rating'] as Map<String, dynamic>)
          : const RatingSummaryModel(),
      reviews: (json['reviews'] as List? ?? const [])
          .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
