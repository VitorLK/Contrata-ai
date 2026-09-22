import 'package:flutter/foundation.dart';

import '../models/professional_profile_model.dart';
import '../services/professional_repository.dart';
import '../models/work_session_model.dart';
import '../services/work_repository.dart';

/// ViewModel do dashboard do profissional. Candidaturas e dados de perfil
/// já vêm de ApplicationsViewModel/ProfessionalProfileViewModel (nenhum
/// endpoint novo para isso — só composição na tela). A única coisa que
/// falta nesses dois é a nota média: GET /professionals/me não calcula
/// avaliação (só GET /professionals/:id, público, calcula), então
/// reaproveita esse mesmo endpoint com o próprio id em vez de criar um
/// endpoint novo só para isso.
class DashboardViewModel extends ChangeNotifier {
  final ProfessionalRepository professionalRepository;
  final WorkRepository workRepository;

  DashboardViewModel({
    required this.professionalRepository,
    required this.workRepository,
  });

  RatingSummaryModel? rating;
  bool isLoadingRating = false;
  bool isLoadingPerformance = false;
  PerformanceModel? performance;
  String? performanceError;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> loadRating(String professionalUserId) async {
    isLoadingRating = true;
    notifyListeners();
    try {
      final publicProfile = await professionalRepository.getPublicProfile(
        professionalUserId,
      );
      rating = publicProfile.rating;
    } catch (_) {
      // A nota média é um complemento do dashboard — uma falha aqui não
      // deveria impedir o resto (candidaturas, completude) de aparecer.
    } finally {
      isLoadingRating = false;
      notifyListeners();
    }
  }

  Future<void> loadPerformance({DateTime? month}) async {
    if (month != null) selectedMonth = DateTime(month.year, month.month);
    isLoadingPerformance = true;
    performanceError = null;
    notifyListeners();
    try {
      performance = await workRepository.getPerformance(
        _monthKey(selectedMonth),
      );
    } catch (_) {
      performanceError = 'Não foi possível carregar os indicadores.';
    } finally {
      isLoadingPerformance = false;
      notifyListeners();
    }
  }

  Future<void> changeMonth(int offset) {
    selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + offset);
    return loadPerformance();
  }
}

String _monthKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
