enum UserRole { cliente, profissional, administrador }

extension UserRoleX on UserRole {
  String get apiValue => switch (this) {
    UserRole.cliente => 'cliente',
    UserRole.profissional => 'profissional',
    UserRole.administrador => 'administrador',
  };

  static UserRole fromApi(String value) {
    return switch (value) {
      'profissional' => UserRole.profissional,
      'administrador' => UserRole.administrador,
      _ => UserRole.cliente,
    };
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? phone;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRoleX.fromApi(json['role'] as String),
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.apiValue,
      'phone': phone,
      'is_active': isActive,
    };
  }
}
