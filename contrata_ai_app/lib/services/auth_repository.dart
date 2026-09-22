import '../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthResult {
  final String token;
  final UserModel user;

  AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Fala com os endpoints /auth/* do back-end.
class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) async {
    final data = await apiClient.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'role': role.apiValue,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    return AuthResult.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await apiClient.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return AuthResult.fromJson(data as Map<String, dynamic>);
  }
}
