import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/session/session_manager.dart';
import '../models/user_model.dart';
import '../services/auth_repository.dart';

enum AuthStatus { idle, loading, error }

/// ViewModel da autenticação (padrão MVVM): expõe o estado de login/cadastro
/// para as Views e delega o acesso a dados ao [AuthRepository].
class AuthViewModel extends ChangeNotifier {
  final AuthRepository authRepository;
  final SessionManager sessionManager;

  AuthViewModel({required this.authRepository, required this.sessionManager});

  AuthStatus status = AuthStatus.idle;
  String? errorMessage;

  bool get isLoggedIn => sessionManager.isLoggedIn;
  UserModel? get currentUser => sessionManager.user;

  Future<bool> login({required String email, required String password}) {
    return _authenticate(
      () => authRepository.login(email: email, password: password),
    );
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) {
    return _authenticate(
      () => authRepository.register(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
      ),
    );
  }

  Future<bool> _authenticate(Future<AuthResult> Function() action) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await action();
      await sessionManager.save(result.token, result.user);
      status = AuthStatus.idle;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      status = AuthStatus.error;
      errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      status = AuthStatus.error;
      errorMessage = 'Não foi possível completar a operação. Tente novamente.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await sessionManager.clear();
    notifyListeners();
  }
}
