import '../core/network/api_client.dart';
import '../models/admin_models.dart';

class AdminDeleteResult {
  final String mode;
  final bool preservedHistory;

  const AdminDeleteResult({required this.mode, required this.preservedHistory});

  factory AdminDeleteResult.fromJson(Map<String, dynamic> json) {
    return AdminDeleteResult(
      mode: json['mode']?.toString() ?? 'excluido',
      preservedHistory: json['preserved_history'] as bool? ?? false,
    );
  }
}

class AdminRepository {
  final ApiClient apiClient;

  const AdminRepository({required this.apiClient});

  Future<AdminOverview> getOverview() async {
    final data = await apiClient.get('/admin/overview', auth: true);
    return AdminOverview.fromJson(data as Map<String, dynamic>);
  }

  Future<List<AdminUser>> listUsers() async {
    final data = await apiClient.get('/admin/users', auth: true);
    return (data as List)
        .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminUser> updateUser(String id, Map<String, dynamic> values) async {
    final data = await apiClient.patch('/admin/users/$id', values, auth: true);
    return AdminUser.fromJson(data as Map<String, dynamic>);
  }

  Future<AdminDeleteResult> deleteUser(String id) async {
    final data = await apiClient.delete('/admin/users/$id', auth: true);
    return AdminDeleteResult.fromJson(data as Map<String, dynamic>);
  }

  Future<List<AdminCompany>> listCompanies() async {
    final data = await apiClient.get('/admin/companies', auth: true);
    return (data as List)
        .map((item) => AdminCompany.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCompany({
    String? id,
    required Map<String, dynamic> values,
  }) async {
    if (id == null) {
      await apiClient.post('/admin/companies', values, auth: true);
    } else {
      await apiClient.patch('/admin/companies/$id', values, auth: true);
    }
  }

  Future<void> deleteCompany(String id) async {
    await apiClient.delete('/admin/companies/$id', auth: true);
  }

  Future<List<AdminServiceRecord>> listServices() async {
    final data = await apiClient.get('/admin/services', auth: true);
    return (data as List)
        .map(
          (item) => AdminServiceRecord.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> updateService(String id, Map<String, dynamic> values) async {
    await apiClient.patch('/admin/services/$id', values, auth: true);
  }
}
