import '../core/network/api_client.dart';
import '../models/application_model.dart';

/// Fala com os endpoints /applications/* do back-end (perspectiva do
/// profissional acompanhando as próprias candidaturas). Ações sobre
/// candidaturas de um serviço específico do cliente (listar/aceitar/
/// recusar) continuam em ServiceRepository, por já pertencerem ao
/// contexto de "gerenciar meu serviço".
class ApplicationRepository {
  final ApiClient apiClient;

  ApplicationRepository({required this.apiClient});

  Future<List<ApplicationModel>> listMine() async {
    final data = await apiClient.get('/applications/mine', auth: true);
    return (data as List)
        .map((e) => ApplicationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> withdraw(String applicationId) async {
    await apiClient.delete('/applications/$applicationId', auth: true);
  }
}
