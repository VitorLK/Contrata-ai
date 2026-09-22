import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/core/session/session_manager.dart';
import 'package:flutter_application_1/models/professional_profile_model.dart';
import 'package:flutter_application_1/services/professional_repository.dart';
import 'package:flutter_application_1/viewmodels/professional_search_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfessionalRepository extends ProfessionalRepository {
  final List<ProfessionalSummaryModel> source;

  _FakeProfessionalRepository(this.source)
    : super(apiClient: ApiClient(sessionManager: SessionManager()));

  @override
  Future<List<ProfessionalSummaryModel>> listProfessionals({
    String? queryText,
    String? category,
    String? state,
    String? city,
    List<ServiceMode> serviceModes = const [],
    PricingType? pricingType,
    double? maxHourlyRate,
    String? availability,
    String? sort,
  }) async => source;
}

void main() {
  const availableElectrician = ProfessionalSummaryModel(
    userId: '1',
    name: 'Ana Elétrica',
    bio: 'Instalações residenciais e manutenção preventiva.',
    skills: ['Elétrica'],
    hourlyRate: 90,
    city: 'Rio do Sul',
    state: 'SC',
    serviceMode: ServiceMode.presencial,
    availability: 'Disponível agora',
    ratingAverage: 4.8,
    ratingCount: 12,
  );
  const remoteDesigner = ProfessionalSummaryModel(
    userId: '2',
    name: 'Bruno Design',
    bio: 'Identidade visual para pequenos negócios.',
    skills: ['Design e criação'],
    hourlyRate: 70,
    city: 'Blumenau',
    state: 'SC',
    serviceMode: ServiceMode.remoto,
    availability: 'Agenda nesta semana',
    ratingAverage: 5,
    ratingCount: 3,
  );

  test(
    'combina localização, categoria, modalidade e disponibilidade',
    () async {
      final viewModel = ProfessionalSearchViewModel(
        professionalRepository: _FakeProfessionalRepository([
          remoteDesigner,
          availableElectrician,
        ]),
      );

      await viewModel.search(
        const ProfessionalSearchFilters(
          query: 'eletrica',
          category: 'Elétrica',
          state: 'SC',
          city: 'Rio do Sul',
          serviceModes: {ServiceMode.presencial},
          maxHourlyRate: 100,
          availableNow: true,
        ),
      );

      expect(viewModel.professionals, [availableElectrician]);
    },
  );

  test('ordena por avaliação e mantém perfis sem nota por último', () async {
    const newProfessional = ProfessionalSummaryModel(
      userId: '3',
      name: 'Carlos',
      skills: ['Consultoria'],
    );
    final viewModel = ProfessionalSearchViewModel(
      professionalRepository: _FakeProfessionalRepository([
        newProfessional,
        availableElectrician,
        remoteDesigner,
      ]),
    );

    await viewModel.search(
      const ProfessionalSearchFilters(sort: ProfessionalSort.bestRated),
    );

    expect(viewModel.professionals.map((item) => item.userId), ['2', '1', '3']);
  });
}
