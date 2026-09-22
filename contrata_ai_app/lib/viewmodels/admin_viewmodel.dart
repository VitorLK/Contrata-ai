import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/admin_models.dart';
import '../services/admin_repository.dart';

enum AdminLoadStatus { idle, loading, loaded, error }

class AdminViewModel extends ChangeNotifier {
  final AdminRepository adminRepository;

  AdminViewModel({required this.adminRepository});

  AdminLoadStatus status = AdminLoadStatus.idle;
  AdminOverview? overview;
  List<AdminUser> users = [];
  List<AdminCompany> companies = [];
  List<AdminServiceRecord> services = [];
  String? errorMessage;
  String? actionMessage;
  bool actionInProgress = false;

  Future<void> loadAll({bool force = false}) async {
    if (!force &&
        (status == AdminLoadStatus.loading ||
            status == AdminLoadStatus.loaded)) {
      return;
    }
    status = AdminLoadStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        adminRepository.getOverview(),
        adminRepository.listUsers(),
        adminRepository.listCompanies(),
        adminRepository.listServices(),
      ]);
      overview = results[0] as AdminOverview;
      users = results[1] as List<AdminUser>;
      companies = results[2] as List<AdminCompany>;
      services = results[3] as List<AdminServiceRecord>;
      status = AdminLoadStatus.loaded;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = AdminLoadStatus.error;
    } catch (_) {
      errorMessage = 'Não foi possível carregar a central administrativa.';
      status = AdminLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> refresh() => loadAll(force: true);

  Future<bool> updateUser(String id, Map<String, dynamic> values) {
    return _runAction(
      action: () => adminRepository.updateUser(id, values),
      successMessage: 'Cadastro atualizado.',
      reload: _reloadUsers,
    );
  }

  Future<bool> deleteUser(String id) async {
    actionInProgress = true;
    actionMessage = null;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await adminRepository.deleteUser(id);
      actionMessage = result.preservedHistory
          ? 'Conta desativada. O histórico operacional foi preservado.'
          : 'Usuário excluído permanentemente.';
      await _reloadUsers();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Não foi possível concluir a exclusão.';
      return false;
    } finally {
      actionInProgress = false;
      notifyListeners();
    }
  }

  Future<bool> saveCompany({String? id, required Map<String, dynamic> values}) {
    return _runAction(
      action: () => adminRepository.saveCompany(id: id, values: values),
      successMessage: id == null
          ? 'Empresa cadastrada.'
          : 'Empresa atualizada.',
      reload: _reloadCompanies,
    );
  }

  Future<bool> deleteCompany(String id) {
    return _runAction(
      action: () => adminRepository.deleteCompany(id),
      successMessage: 'Empresa excluída.',
      reload: _reloadCompanies,
    );
  }

  Future<bool> updateService(String id, Map<String, dynamic> values) {
    return _runAction(
      action: () => adminRepository.updateService(id, values),
      successMessage: 'Registro de serviço ajustado e auditado.',
      reload: _reloadServices,
    );
  }

  Future<void> _reloadUsers() async {
    final results = await Future.wait<dynamic>([
      adminRepository.listUsers(),
      adminRepository.getOverview(),
    ]);
    users = results[0] as List<AdminUser>;
    overview = results[1] as AdminOverview;
  }

  Future<void> _reloadCompanies() async {
    final results = await Future.wait<dynamic>([
      adminRepository.listCompanies(),
      adminRepository.getOverview(),
    ]);
    companies = results[0] as List<AdminCompany>;
    overview = results[1] as AdminOverview;
  }

  Future<void> _reloadServices() async {
    final results = await Future.wait<dynamic>([
      adminRepository.listServices(),
      adminRepository.getOverview(),
    ]);
    services = results[0] as List<AdminServiceRecord>;
    overview = results[1] as AdminOverview;
  }

  Future<bool> _runAction({
    required Future<dynamic> Function() action,
    required String successMessage,
    required Future<void> Function() reload,
  }) async {
    actionInProgress = true;
    actionMessage = null;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      await reload();
      actionMessage = successMessage;
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Não foi possível concluir esta ação.';
      return false;
    } finally {
      actionInProgress = false;
      notifyListeners();
    }
  }
}
