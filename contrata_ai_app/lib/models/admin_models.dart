double _asDouble(dynamic value) => value == null
    ? 0
    : value is num
    ? value.toDouble()
    : double.tryParse(value.toString()) ?? 0;

int _asInt(dynamic value) => value == null
    ? 0
    : value is num
    ? value.toInt()
    : int.tryParse(value.toString()) ?? 0;

DateTime _asDate(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();

class AdminMonthlyPoint {
  final String month;
  final int newUsers;
  final int completedServices;

  const AdminMonthlyPoint({
    required this.month,
    required this.newUsers,
    required this.completedServices,
  });

  factory AdminMonthlyPoint.fromJson(Map<String, dynamic> json) {
    return AdminMonthlyPoint(
      month: json['month']?.toString() ?? '',
      newUsers: _asInt(json['new_users']),
      completedServices: _asInt(json['completed_services']),
    );
  }
}

class AdminActivity {
  final String kind;
  final String title;
  final String detail;
  final DateTime createdAt;

  const AdminActivity({
    required this.kind,
    required this.title,
    required this.detail,
    required this.createdAt,
  });

  factory AdminActivity.fromJson(Map<String, dynamic> json) {
    return AdminActivity(
      kind: json['kind']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      createdAt: _asDate(json['created_at']),
    );
  }
}

class AdminOverview {
  final int totalUsers;
  final int clients;
  final int professionals;
  final int activeUsers;
  final int newUsers30d;
  final int totalCompanies;
  final int activeCompanies;
  final int totalServices;
  final int openServices;
  final int inProgressServices;
  final int completedServices;
  final int cancelledServices;
  final int completedSessions;
  final int workedMinutes;
  final double transactedAmount;
  final double completionRate;
  final List<AdminMonthlyPoint> monthly;
  final List<AdminActivity> recentActivity;

  const AdminOverview({
    required this.totalUsers,
    required this.clients,
    required this.professionals,
    required this.activeUsers,
    required this.newUsers30d,
    required this.totalCompanies,
    required this.activeCompanies,
    required this.totalServices,
    required this.openServices,
    required this.inProgressServices,
    required this.completedServices,
    required this.cancelledServices,
    required this.completedSessions,
    required this.workedMinutes,
    required this.transactedAmount,
    required this.completionRate,
    required this.monthly,
    required this.recentActivity,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>? ?? {};
    final companies = json['companies'] as Map<String, dynamic>? ?? {};
    final services = json['services'] as Map<String, dynamic>? ?? {};
    final operation = json['operation'] as Map<String, dynamic>? ?? {};
    return AdminOverview(
      totalUsers: _asInt(users['total_users']),
      clients: _asInt(users['clients']),
      professionals: _asInt(users['professionals']),
      activeUsers: _asInt(users['active_users']),
      newUsers30d: _asInt(users['new_users_30d']),
      totalCompanies: _asInt(companies['total']),
      activeCompanies: _asInt(companies['active']),
      totalServices: _asInt(services['total']),
      openServices: _asInt(services['open']),
      inProgressServices: _asInt(services['in_progress']),
      completedServices: _asInt(services['completed']),
      cancelledServices: _asInt(services['cancelled']),
      completedSessions: _asInt(operation['completed_sessions']),
      workedMinutes: _asInt(operation['worked_minutes']),
      transactedAmount: _asDouble(operation['transacted_amount']),
      completionRate: _asDouble(services['completion_rate']),
      monthly: (json['monthly'] as List? ?? [])
          .map(
            (item) => AdminMonthlyPoint.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      recentActivity: (json['recent_activity'] as List? ?? [])
          .map((item) => AdminActivity.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AdminUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;
  final String? city;
  final String? state;
  final List<String> skills;
  final double? hourlyRate;
  final String? companyName;
  final int serviceCount;
  final int completedCount;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
    required this.isActive,
    required this.createdAt,
    required this.city,
    required this.state,
    required this.skills,
    required this.hourlyRate,
    required this.companyName,
    required this.serviceCount,
    required this.completedCount,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      phone: json['phone']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _asDate(json['created_at']),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      skills: (json['skills'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      hourlyRate: json['hourly_rate'] == null
          ? null
          : _asDouble(json['hourly_rate']),
      companyName: json['company_name']?.toString(),
      serviceCount: _asInt(json['service_count']),
      completedCount: _asInt(json['completed_count']),
    );
  }
}

class AdminCompany {
  final String id;
  final String legalName;
  final String? tradeName;
  final String document;
  final String? email;
  final String? phone;
  final String? city;
  final String? state;
  final String status;
  final String? ownerUserId;
  final String? ownerName;
  final String? ownerEmail;
  final int serviceCount;
  final DateTime createdAt;

  const AdminCompany({
    required this.id,
    required this.legalName,
    required this.tradeName,
    required this.document,
    required this.email,
    required this.phone,
    required this.city,
    required this.state,
    required this.status,
    required this.ownerUserId,
    required this.ownerName,
    required this.ownerEmail,
    required this.serviceCount,
    required this.createdAt,
  });

  String get displayName =>
      tradeName?.isNotEmpty == true ? tradeName! : legalName;

  factory AdminCompany.fromJson(Map<String, dynamic> json) {
    return AdminCompany(
      id: json['id'].toString(),
      legalName: json['legal_name']?.toString() ?? '',
      tradeName: json['trade_name']?.toString(),
      document: json['document']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      status: json['status']?.toString() ?? 'ativa',
      ownerUserId: json['owner_user_id']?.toString(),
      ownerName: json['owner_name']?.toString(),
      ownerEmail: json['owner_email']?.toString(),
      serviceCount: _asInt(json['service_count']),
      createdAt: _asDate(json['created_at']),
    );
  }
}

class AdminServiceRecord {
  final String id;
  final String title;
  final String? category;
  final double? budget;
  final String status;
  final DateTime scheduledDate;
  final String? city;
  final String? state;
  final String? serviceMode;
  final String clientName;
  final String? professionalName;
  final String? workStatus;
  final DateTime createdAt;

  const AdminServiceRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.budget,
    required this.status,
    required this.scheduledDate,
    required this.city,
    required this.state,
    required this.serviceMode,
    required this.clientName,
    required this.professionalName,
    required this.workStatus,
    required this.createdAt,
  });

  factory AdminServiceRecord.fromJson(Map<String, dynamic> json) {
    return AdminServiceRecord(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString(),
      budget: json['budget'] == null ? null : _asDouble(json['budget']),
      status: json['status']?.toString() ?? '',
      scheduledDate: _asDate(json['scheduled_date']),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      serviceMode: json['service_mode']?.toString(),
      clientName: json['client_name']?.toString() ?? '',
      professionalName: json['professional_name']?.toString(),
      workStatus: json['work_status']?.toString(),
      createdAt: _asDate(json['created_at']),
    );
  }
}
